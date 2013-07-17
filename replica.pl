#!/usr/bin/perl
#   Nodo del sistema distribuido de control de versiones

package replica;

use lib qw(.);
use lib qw(./lib/perl5/site_perl/5.12.4/);
use lib qw(./lib/lib/perl5/site_perl/5.12.4);
use utf8;
use strict;
use threads;
use threads::shared;

use Data::Dumper;
use Digest::MD5;
use Frontier::Client;
use Frontier::Daemon;
use IO::Socket::Multicast;
use IO::Socket::PortState qw(check_ports);
use Net::Ping;
use Net::SFTP::Foreign;
use RPC::XML;

use Archivo;
use InfoNodo;

use constant K              => 2; 
use constant LOG            => 1;
use constant DEBUG          => 0;
use constant MC_DESTINATION => '226.1.1.4:2000';
use constant MC_GROUP       => '226.1.1.4';
use constant MC_PORT        => '2000';
use constant DNS_URL        => 'titan.ldc.usb.ve';
use constant DNS_PORT       => '8083';
use constant COORD_RPC_PORT => '8081';
use constant REP_RPC_PORT   => '8082';


#   Variables globales de un servidor replica
my $coord      :shared;
my %tablaNodos :shared;
my %pidRep     :shared;
my $hostname = `hostname`;
my $raiz     = '/tmp/scm/';
my $my_url   = gethostbyname($hostname);
my $my_pid   = getppid;
chomp($my_pid);
chomp($hostname);

#
#   Subrutinas propias de todos los servidores replica
#

sub getCoord {
    print "Contactando al DNS para saber el estado del coordinador...\n" if DEBUG;
    my $server_url = 'http://' . DNS_URL . ':' . DNS_PORT . '/RPC2';
    my $server = Frontier::Client->new(url => $server_url, use_objects => 0);
    my $arg = $server->string($hostname);
    my $result = $server->call('dns.coordinador', $arg);
    my $aux = $result->{'coordinador'};
    chomp($aux);
    print "El coordinador es: $aux\n" if DEBUG;
    return $aux;
}

#
sub setCoord {
    print "Cambiando de coordinador...\n" if DEBUG;
    my $coordViejo = $coord;

    my @pids_todos = sort keys %tablaNodos;
    my $pid_nuevo_coord;
    foreach (@pids_todos) {
        if ($tablaNodos{$_}->estado == 5) {
            $pid_nuevo_coord = $_;
            last;
        }
    }

    $coord = $tablaNodos{$pid_nuevo_coord}->nombre;
    if ($coord eq $hostname) {
        my $server_url = 'http://' . DNS_URL . ':' . DNS_PORT . '/RPC2';
        my $server     = Frontier::Client->new(url => $server_url, use_objects => 0);
        my $arg        = $server->string($hostname);
        my $result     = $server->call('dns.actualizar', $arg);
        print "Coordinador cambiado en el DNS\n" if DEBUG;
    }
}

#   Esta rutina verifica el estado del coordinador actual
#   En caso de darse cuenta de que el coordinador no responde
#   lo cambia al proximo de la lista de coordinadores
#   y actualiza al DNS en caso de alguien no lo haya hecho
sub chequearCoord {
    my $port = COORD_RPC_PORT;

    my %port_hash = (
        tcp => {
            $port => {},
        }
    );

    my $timeout = 5;

    while ($coord ne $hostname) {
        sleep($timeout);
        print "Revisando coordinador: $coord\n" if DEBUG;
        print "Revisando el puerto: " . COORD_RPC_PORT . "\n" if DEBUG;
        my $host_hr = check_ports($coord, $timeout, \%port_hash);
        my $coordVivo = $host_hr->{tcp}{$port}{open};
        if (!$coordVivo) {
            print "Coordinador muerto. Cambiando coordinador\n" if DEBUG;
            my @aux = grep { $tablaNodos{$_}->nombre eq $coord } keys %tablaNodos;
            my $pid_coordinador = shift @aux;
            print "PID $pid_coordinador\n";
            $tablaNodos{$pid_coordinador}->bajar_contador();
            &setCoord();
        } else {
            print "Coordinador $coord activo.\n" if DEBUG;
        }
    }
    return 1;
}

#   Esta rutina notifica a todos los servidores la incorporacion de
#   este servidor replica enviando con multicast su hostname y pid
sub notificar {
    print "Notificando mi informacion al grupo multicast\n" if DEBUG;
    my $socket = IO::Socket::Multicast->new(PeerAddr=>MC_DESTINATION);
    my $datos  = "1,";
    $datos .= $hostname . ",";
    $datos .= $my_pid;
    $socket->send($datos) || die "No se pudo notificar al grupo: $!";
    print "Notificacion enviada al grupo multicast\n" if DEBUG;
}

#   Esta rutina escucha multicast y dependiendo del codigo que reciba
#   ejecuta la rutina correspondiente
sub escuchar {
    print "Esuchando futuras acciones como servidor replica...\n" if DEBUG;

    my $sock = IO::Socket::Multicast->new(Proto=>'udp', LocalPort=>MC_PORT);
    $sock->mcast_add(MC_GROUP) || die "No se pudo asociar al grupo multicast: $!\n"; 

    while (1) {
        my $data;
        print "Esperando una accion...\n" if DEBUG;
        next unless $sock->recv($data,1024);

        print "Manejando un mensaje multicast...\n" if DEBUG;

        my @datos = split(',',$data);

        my $tipo_mensaje = shift @datos;

        #   Aqui se debe verificar el tipo de mensaje que llego
        if ($tipo_mensaje == 1) {
            print "Agregando un nuevo servidor\n" if DEBUG;
            my $hostname = $datos[0];
            my $pid = $datos[1];
            $pid = $tablaNodos{$hostname}->pid if (exists $tablaNodos{$hostname});
            &agregarServidor($hostname, $pid);
        }
        if ($tipo_mensaje == 2){
            my $usuario = shift @datos;
            my $proyecto = shift @datos;
            my $archivo = shift @datos;
            my $version = shift @datos;
            my $checksum = shift @datos;
            print "Nuevo commit $archivo version: $version en las replicas @datos\n" if DEBUG;
            my $nombre_archivo = "$usuario.$proyecto.$archivo";
            foreach (@datos){
                my $arch;
                my $arch = $tablaNodos{$_}->buscar_archivo($nombre_archivo);
                if (defined($arch)){
                    $arch->agregar_version($version=>$checksum);    
                }else{
                  $archivo = shared_clone(Archivo->new('nombre' => $nombre_archivo));
                  $archivo->agregar_version($version => $checksum);
                  $tablaNodos{$_}->agregar_archivo($nombre_archivo => $archivo);
                }
            }
            #print Dumper (\%tablaNodos); 
        }
        if ($tipo_mensaje == 10) {
            #   Mensaje de notificacion de un servidor muerto
        }

    }
}

#   Esta rutina se encarga de agregar un nuevo servidor a la tabla 
sub agregarServidor {
    my ($servidor, $pid) = @_;
    $pidRep{$servidor} = $pid;

    print "Agregando:$servidor:$pid\n" if DEBUG;

    #   Agregamos la informacion del nuevo nodo a la tabla
    my $nodo = $tablaNodos{"$pid"}; 
    if (defined $nodo) {
        #   El nodo revivio
        if ($nodo->estado == 0) {
            my $nuevo :shared = shared_clone(InfoNodo->new);
            bless ($nuevo, 'InfoNodo');
            $nuevo->nombre($servidor);
            $nuevo->pid($nodo->pid);
            $tablaNodos{$nodo->pid} = $nuevo;
        }
        $tablaNodos{$pid}->reset_contador();
    } else {
        my $nuevo :shared = shared_clone(InfoNodo->new);
        bless ($nuevo, 'InfoNodo');
        $nuevo->nombre($servidor);
        $nuevo->pid($pid);
        $tablaNodos{$pid} = $nuevo;
    }
}

# Rutina que crea el directorio raiz
sub crearRaiz{
    mkdir $raiz;
}
# Rutina que borra todos los archivos almacenados en la replica
sub wipe {
    system("rm -r $raiz/*i");
    &crearRaiz();
}

#   Metodo que monitorea el estado de los servidores replica del sistema
sub chequearReplicas {

    my $port = MC_PORT;

    my %port_hash = (
        udp => {
            $port => {},
        }
    );

    my $timeout = 5;

    while (1) {
        sleep($timeout);
        foreach my $replica (values %tablaNodos) {
            my $nombre_replica = $replica->nombre;
            next if $nombre_replica eq $hostname;
            print "Revisando: $nombre_replica\n" if DEBUG;
            my $host_hr = check_ports($nombre_replica, $timeout, \%port_hash);
            my $replicaViva = $host_hr->{udp}{$port}{open};
            if (!$replicaViva) {
                print "Servidor $nombre_replica no responde.\n" if DEBUG;
                $tablaNodos{"$replica->pid"}->bajar_contador;
                if ($tablaNodos{"$replica->pid"}->estado == 0) {
                    print "El servidor $nombre_replica murio\n" if LOG;
                    &notificarServidorMuerto($nombre_replica);
                    &replicarServidor();
                }
            } else {
                print "Todo bien con $nombre_replica.\n" if DEBUG;
            }
        }
    }
}

#   Metodos expuestos por RPC en los servidores replica
sub getTabla {
    my $server_url = "http://$coord:" . COORD_RPC_PORT . '/RPC2';
    my $server = Frontier::Client->new(url => $server_url);

    my $result = $server->call('coordinador.tabla');
    my $tablaStr = $result->{'tabla'};

    %tablaNodos = &fromStr2Tabla($tablaStr);

    print "Tabla de InfoNodos que me llego de: $coord\n" if DEBUG;
    print Dumper (\%tablaNodos) if DEBUG;

    &getTabla() unless exists $tablaNodos{"$my_pid"};
    &crearRaiz;
    wipe($my_pid) if $tablaNodos{$my_pid}->contar_archivos() == 0;
    1;
}

#
#   Rutinas propias del coordinador
#

# Metodos RPC expuestos por el coordinador 
sub tabla {
    my $tablaStr = &fromTabla2Str();

    print "Tabla que se va a enviar...\n" if DEBUG;
    print Dumper \%tablaNodos if DEBUG;

    return {'tabla' => $tablaStr};
}

# Esta rutina recibe un archivo del cliente para hacer el commit.
# Se verifica que el checksum del archivo recibido sea distinto al 
# checksum de la ultima version, de lo contrario no se realiza el commit
sub clienteCommit{
    my $usuario = shift;
    my $proyecto = shift;
    my $archivo = shift;
    my $check = &commit($usuario, $proyecto, $archivo);
    if ($check){
        return {'clienteCommit' =>"$archivo Up to date\n"};
    }else{     
        return {'clienteCommit' => "Commit realizado\n"};
    }
}

#
sub clientePull{
    my $usuario = shift;
    my $proyecto = shift;
    my $archivo = shift;
    my $version = shift;
    print "Realizando pull archivo: $archivo version: $version  usuario: $usuario\n" if DEBUG;
    &pull($usuario,$proyecto,$archivo,$version);
    return {'clientePull' => 1};
}

#   Inicializa las funciones del coordinador
sub iniciarCoordinador {
    print "Arrancando el RPC de coordinador ...\n" if DEBUG;
    
    # Hash replica -> pid
    while (my($key,$value) = each %tablaNodos){
        my $host = $value->nombre();
        $pidRep{$value->nombre} = $key;
    }

    #   Metodos expuestos por RPC por el coordinador
    my $methods = {
        'coordinador.tabla' => \&tabla,
        'coordinador.clienteCommit' => \&clienteCommit,
        'coordinador.clientePull' => \&clientePull,
    };
    Frontier::Daemon->new(LocalPort => COORD_RPC_PORT, methods => $methods)
        or die "No se pudo iniciar el servidor RPC: $!";
}

#   Metodos locales del coordinador

#   Subrutina que avisa por multicast a los nodos del sistema que un 
#   servidor replica murio
sub notificarServidorMuerto {
    my $servidor = shift;
    print "Notificando la caida del servidor $servidor.\n" if DEBUG;
    my $socket = IO::Socket::Multicast->new(PeerAddr=>MC_DESTINATION);
    my $datos  = "10,";  #   10 es el codigo para indicar que un servidor murio
    $datos .= $hostname;
    $socket->send($datos) || die "No se pudo notificar al grupo: $!";
    print "Notificacion enviada al grupo multicast\n" if DEBUG;
    1;
}

#   Subrutina que replica los archivos de un servidor que haya muerto en los demas
#   nodos del sistema. Debe garantizar balanceo de cargas y tolerancia suficiente
sub replicarServidor {
    my $servidor = shift;
    1;
}

#   Transforma el hash de InfoNodos en formato de listas para transmitirlo
#   por RPC
sub fromTabla2Str {
    my $string = "";
    foreach (values %tablaNodos) {
        my $nodo = $_;
        bless $nodo, 'InfoNodo';
        $string .= $nodo;
    }
    return $string;
}

#   Transforma el hash de listas con la informacion de los nodos del sistema
#   en un hash de InfoNodo para trabajar localmente con la informacion
sub fromStr2Tabla {
    my $tablaStr = shift;
    my %result;
    my @arrayIN = split ('&', $tablaStr); 
    foreach (@arrayIN) {
        my @attr = split ('\#', $_);
        my @nep = split (',', shift @attr);
        my $nombre = shift @nep;
        my $pid    = shift @nep;
        my $estado = shift @nep;
        my $nodo :shared = shared_clone(InfoNodo->new);
        bless ($nodo, 'InfoNodo');
        $nodo->nombre($nombre);
        $nodo->pid($pid);
        $nodo->estado($estado);
        #  Agregando archivos
        foreach (@attr) {
            my @archivoArray = split (',', $_);
            my $nombre_archivo = shift @archivoArray;
            my $archivo = Archivo->new('nombre' => $nombre_archivo);
            while (@archivoArray > 0) {
                my $version = shift @archivoArray;
                my $checksum = shift @archivoArray;
                $archivo->agregar_version(
                    $version => $checksum,
                );
            }
            $nodo->agregar_archivo($nombre_archivo => $archivo);
        }
        $result{$pid} = $nodo;
    }
    %result;
}

#
#
sub commit {
    my $usuario = shift;
    my $proyecto = shift;
    my $archivo = shift;
    my $checksum = &checksum($archivo);
    my ($version, $checksumL, @replicas) = &getRep($usuario,$proyecto,$archivo);
    print "Realizando commit del $archivo version: $version usuario: $usuario proyecto: $proyecto Replicas: @replicas\n"; 
    if ($checksum ne $checksumL) {
        &send2rep($usuario,$proyecto,$archivo,$version+1,@replicas);
        return 0;
    }else{
        return 1;
    }
}

#
#
sub pull{
    my $usuario = shift;
    my $proyecto = shift;
    my $archivo = shift;
    my $version = shift;
    my $checkL;
    my $checkR;
    my @arreglar;
    my $rep;

    if (defined($version)) {
        print "error\n" unless (&versionOK($usuario,$proyecto,$archivo,$version));
    }else{
        $version = &getVersion($usuario,$proyecto,$archivo);
    }

    ($checkR,$rep,@arreglar) = &validarChecksum($usuario,$proyecto,$archivo,$version);
    while ($checkR ne $checkL) {
        &getFromRep($usuario,$proyecto,$archivo,$version,$rep);
        $checkL = &checksum($archivo);
    }
    &arreglarRep($usuario,$proyecto,$archivo,$version,@arreglar) if (@arreglar);
}

sub versionOK{
    my $usuario = shift;
    my $proyecto = shift;
    my $archivo = shift;
    my $version = shift;
    $archivo = "$usuario.$proyecto.$archivo";
    my $arch;
    while (my($pid, $rep) = each %tablaNodos) {

        $arch = $rep->buscar_archivo($archivo); 
        if (defined($arch)) {
            my $versionTabla = $arch->contar_versiones();
            return 0 if ($versionTabla < $version);
            return 1;
        }
    }
    return 0;
}

sub arreglarRep{
    my $usuario = shift;
    my $proyecto = shift;
    my $archivo = shift;
    my $version = shift;
    my @replicas = @_;
    print "Reenviando archivo a replicas con checksum malo Replicas: @replicas\n" if DEBUG;
    &send2rep($usuario,$proyecto,$archivo,$version,@replicas);
}

# Rutina que calcula el checksum de un archivo
sub checksum{
    my $archivo = shift;
    my $checksum;
    eval {
        open(FILE, "/tmp/$archivo") or die "No se pudo encontrar el archivo: $archivo\n";
        my $ctx = Digest::MD5->new;
        $ctx->addfile(*FILE);
        $checksum = $ctx->hexdigest;
        close(FILE);
    }; 
    return $checksum;
}

# Rutina que valida los checksum del archivo en todas las replicas
# Retorna el checksum valido y la replica a solicitar
# Si existe un error en alguno de los checksum reenvia el archivo a 
# la replica con el checksum incorrecto
sub validarChecksum {
    my $usuario = shift;
    my $proyecto = shift;
    my $archivo = shift;
    my $version = shift;
    my ($v,$c,@replicas) =  &getRep($usuario,$proyecto,$archivo);
    my %checksums;
    shift @replicas;
    foreach(@replicas){
        my $rep_url = "http://$_:" . REP_RPC_PORT . '/RPC2';
        my $rep = Frontier::Client->new(url => $rep_url);
        my $result = $rep->call('rep.checksum',$archivo,$version);
        push (@{$checksums{$result}},$_);
    }

    my @modaCheck;
    my $moda;
    my @arreglar;
    while(my($check,@rep) = each %checksums){
        if (@modaCheck < @rep){
            if (@modaCheck){
                push(@arreglar,$_) foreach @modaCheck;
            }
            ($moda,@modaCheck) = ($check,@rep);
        }
    }
    return($moda,$modaCheck[0],@arreglar);
}

#
sub notificarCommit{
    my $usuario = shift;
    my $proyecto = shift;
    my $archivo = shift;
    my $version = shift;
    my $checksum = shift;
    my @reps = @_;
    
    print "Notificando commit  del archivo $usuario.$proyecto.$archivo al grupo multicast\n" if DEBUG;
    my $socket = IO::Socket::Multicast->new(PeerAddr=>MC_DESTINATION);
    my $datos  = "2,";
    $datos .= "$usuario.$proyecto.$archivo,";
    $datos .= $version . ",";
    $datos .= $checksum . ",";
    $datos .= "$_," foreach(@reps);
    $socket->send($datos) || die "No se pudo notificar al grupo: $!";
    print "Notificacion enviada al grupo multicast\n" if DEBUG;
}

# Rutina que envia un archivo a la replica
# Parametros
# @servidores: lista de los servidores a los que se enviara el archivo
# $archivo: achivo que se enviara
sub send2rep{
    my $usuario = shift;
    my $proyecto = shift;
    my $archivo = shift;
    my $version = shift;
    my @reps = @_;
    my @pids;
    foreach(@reps) {
        print "Enviando $archivo a $_\n";
        my $host = $_;
        my $sftp = Net::SFTP::Foreign->new(host=>$host, user=>'javier');
        $sftp->mkpath("$raiz/$usuario/$proyecto/$archivo");
        $sftp->put("/tmp/$archivo","$raiz/$usuario/$proyecto/$archivo/$version");
        push(@pids,$pidRep{$_});
    }
    #   NOTIFICAR A TODO EL MUNDO EL ENVIO DE ARCHIVOS
    #   PARA QUE ACTUALICEN SU TABLA
    my $checksum = &checksum($archivo);
    print "Notificando commit a @pids\n" if DEBUG;
    &notificarCommit($usuario,$proyecto,$archivo,$version,$checksum,@pids);
}

# Rutina que recibe un archivo de una replica
# Parametros
# $archivo
# $version (la ultima por defecto)
# $replica
sub getFromRep {
    my $usuario = shift;
    my $proyecto = shift;
    my $archivo = shift;
    my $rep = shift;
    my $version = shift;
    $version = &getVersion($usuario,$proyecto,$archivo) unless defined($version);
    my $sftp = Net::SFTP::Foreign->new(host=>$rep, user=>'javier');
    $sftp->get("$raiz/$usuario/$proyecto/$archivo/$version","/tmp/$archivo");

}

#   Rutina que busca las replicas que tienen un archivo dado y la 
#   ultima version disponible 
sub getRep {
    my $usuario =shift;
    my $proyecto = shift;
    my $archivo = shift;
    my $version = 0;
    my @replicas;
    my $checksum;

    $archivo = "$usuario.$proyecto.$archivo";
    print "Get rep archivo $archivo\n";
    while (my($pid, $rep) = each %tablaNodos) {
        my $arch;
        $arch = $rep->buscar_archivo($archivo);
        if (defined($arch)) {
            push(@replicas,$rep->nombre());
            $version = $arch->contar_versiones;
            $checksum = $arch->get_version($version);
          }

      }
      @replicas = &lowRep unless (@replicas);
      return ($version,$checksum,@replicas);
}

# Rutina que busca las k replicas con menos carga
#
sub lowRep {
    my %cp;
    my @replicas;
    while (my($pid, $rep) = each %tablaNodos) {
        print "Entre\n";
        print $rep->nombre() . "\n";
        push (@{$cp{$rep->contar_archivos}},$rep->nombre());
    }  
    my @cargas = (sort keys %cp);
    
    my $krep = 0;
    my $key = shift @cargas;
    while ($krep < K){
        $key = shift @cargas unless ($cp{$key});
        push(@replicas, shift @{$cp{$key}});
        $krep++;
    }
    return @replicas;
}

# Rutina que retorna la ultima version de un archivo
sub getVersion {
    my $usuario;
    my $proyecto;
    my $archivo = shift;
    my $version;
    $archivo = "$usuario.$proyecto.$archivo";
    while (my($pid, $rep) = each %tablaNodos) {
        my $arch;
        $arch = $rep->buscar_archivo($archivo); 
        if (defined($arch)) {
            print "Buscando la version del archivo $archivo\n" if DEBUG;
            $version = $arch->contar_versiones();
            last;
        }
        return $version;
    }
}

############
#   Main   #
############


#   Consultar al dns quien es el coordinador
$coord = &getCoord();
mkdir $raiz;
#   Enviar a todos el hostname y pid. 
&notificar() unless $coord eq $hostname;
$pidRep{$hostname} = $my_pid if $coord eq $hostname;
$coord eq $hostname ? &agregarServidor($hostname, $my_pid) : &getTabla();

print "Iniciando el hilo de escucha por RPC como servidor replica.\n" if DEBUG;
threads->new(\&escuchar)->detach;

print "Iniciando el hilo de monitoreo del coordinador\n" if DEBUG;
my $hiloCoord = threads->new(\&chequearCoord);

#   Codigo como coordinador
$hiloCoord->join();
print "Iniciando el hilo de monitoreo de replicas\n" if DEBUG;
threads->new(\&iniciarCoordinador)->detach;
&chequearReplicas();
