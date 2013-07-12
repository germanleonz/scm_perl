#!/usr/bin/perl
#   Nodo del sistema distribuido de control de versiones

use lib qw(.);
#use lib qw(./lib/perl5/site_perl/5.12.4/);
##use lib qw(./lib/lib/perl5/site_perl/5.12.4);
#use lib qw(./lib/lib/perl5/site_perl/5.12.4/darwin-thread-multi-2level);
use utf8;
use strict;
use threads;
use threads::shared;

use IO::Socket::Multicast;
use IO::Socket::PortState qw(check_ports);
#use Hash::PriorityQueue;
use Frontier::Client;
use Frontier::Daemon;
use RPC::XML;
#use XML::Simple;
use Net::Ping;
use Data::Dumper;

use Archivo;
use InfoNodo;

use constant LOG            => 1;
use constant DEBUG          => 1;
use constant MC_DESTINATION => '226.1.1.4:2000';
use constant MC_GROUP       => '226.1.1.4';
use constant MC_PORT        => '2000';
#use constant DNS_URL        => 'geidi.ldc.usb.ve';
use constant DNS_URL        => '192.168.3.39';
use constant DNS_PORT       => '8083';
use constant COORD_RPC_PORT => '8081';


#   Variables globales de un servidor replica
my $coord  :shared;
my %tablaNodos :shared;
my $hostname = `hostname`;
my $my_url = gethostbyname($hostname);
my $my_pid = getppid;
my @threads;
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

sub setCoord {
    print "Cambiando de coordinador...\n" if DEBUG;
    my @aux = sort keys %tablaNodos;
    my $posibleCoord = shift @aux;
    my $aux = &getCoord();
    unless ($posibleCoord eq $aux) {
        my $server_url = 'http://' . DNS_URL . ':' . DNS_PORT . '/RPC2';
        my $server = Frontier::Client->new(url => $server_url, use_objects => 0);
        my $arg = $server->string($hostname);
        my $result = $server->call('dns.actualizar', $arg);
        print "Coordinador cambiado\n" if DEBUG;
    }
}

#   Esta rutina verifica el estado del coordinador actual
#   En caso de darse cuenta de que el coordinador no responde
#   lo cambia al proximo de la lista de coordinadores
#   y actualiza al DNS en caso de alguien no lo haya hecho
sub chequearCoord {
    my %porthash = {"$coord" => COORD_RPC_PORT};
    my $timeout = 5;
    while (1) {
        sleep($timeout);
        next if ($coord eq "");
        print "Revisando coordinador: $coord\n" if DEBUG;
        if (!$porthash{"$coord"}->{open}) {
            print "Coordinador muerto. Cambiando coordinador\n" if DEBUG;
            &setCoord();
        } else {
            print "Coordinador $coord activo.\n" if DEBUG;
        }
    }
}

# Esta rutina notifica a todos los servidores la incorporacion de este servidor
# replica enviando con multicast su hostname y pid
sub notificar {
    print "Notificando mi informacion al grupo multicast\n" if DEBUG;
    my $socket = IO::Socket::Multicast->new(PeerAddr=>MC_DESTINATION);
    my $datos  = "1,";
    $datos .= $hostname . ",";
    $datos .= $my_pid;
    $socket->send($datos) || die "No se pudo notificar al grupo: $!";
    print "Notificacion enviada al grupo multicast\n" if DEBUG;
}

# Esta rutina escucha multicast y dependiendo del codigo que reciba ejecuta la
# rutina correspondiente
sub escuchar {
    print "Esuchando futuras acciones como servidor replica...\n" if DEBUG;
    my $sock = IO::Socket::Multicast->new(LocalPort=>MC_PORT);
    $sock->mcast_add(MC_GROUP) || die "No se pudo asociar al grupo multicast: $!\n"; 

    while (1) {
        my $data;
        next unless $sock->recv($data,1024);

        print "Me llego un mensaje de multicast\n";

        my @datos = split(',',$data);

        #   Aqui se debe verificar el tipo de mensaje que llego

        &agregarServidor($datos[1], $datos[2]) if ($datos[0] eq "1");
    }
}

#   Esta rutina se encarga de agregar un nuevo servidor a la tabla 
sub agregarServidor {
    my ($servidor, $pid) = @_;

    print "Agregando:$servidor:$pid\n" if DEBUG;

    #   Agregamos la informacion del nuevo nodo a la tabla
    my $nodo = $tablaNodos{"$pid"}; 
    if (defined $nodo) {
    } else {
        my $nuevo :shared = shared_clone(InfoNodo->new);
        bless ($nuevo, 'InfoNodo');
        $nuevo->nombre($servidor);
        $nuevo->pid($pid);
        $tablaNodos{$pid} = $nuevo;
    }
}

#   
sub wipe {
    #body ...
}

#   Metodo que monitorea el estado de los servidores replica del sistema
sub chequearReplicas {
    my %porthash = {};
    #my $timeout = 5;
    while (1) {
        foreach my $replica (values %tablaNodos) {
            my $nombre_replica = $replica->nombre;
            print "Revisando: $\n" if DEBUG;
            $porthash{"$nombre_replica"} = MC_PORT;
            if (!$porthash{"$nombre_replica"}->{open}) {
                print "Servidor $nombre_replica no responde.\n" if DEBUG;
                $tablaNodos{"$replica->pid"}->bajar_contador;
                &notificarServidorMuerto($nombre_replica);
                &replicarServidor();
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
    %tablaNodos = $result->{'tabla'};

    print "IMPRIMIENDO LO QUE ME LLEGO\n";
    while(my($key,$value) = each %tablaNodos) {
        print "$key=>\n";
        print Dumper $value;
    }
    print "TABLA IMPRESA LO QUE ME LLEGO\n";

    #%tablaNodos = toTabla(%tablaLista);

    &getTabla() unless exists $tablaNodos{"$my_pid"};

    print "Tabla recibida del coordinador ...\n" if DEBUG;
    while(my($key,$value) = each %tablaNodos) {
        print "$key => $value\n"
    }
    print "La tabla recibida ya fue impresa.\n" if DEBUG;

    wipe($my_pid) if $tablaNodos{$my_pid}->contar_archivos() == 0;

    1;
}

#
#   Rutinas propias del coordinador
#

# Metodos RPC expuestos por el coordinador 
sub tabla {

    print "Alguien pidio mi tabla\n";
    print "Imprimiendo Tabla local como hash de InfoNodos\n" if DEBUG;
    while (my($key, $value) = each %tablaNodos) {
        print "$key =>";
        print Dumper $value;
    }
    #print "Impresa la Tabla local como hash de InfoNodos\n" if DEBUG;
    #my %tablaListas = &fromTabla();

    #print "Tabla que se va a enviar...\n" if DEBUG;
    #while (my($key, $value) = each %tablaListas) {
        #print "$key =>";
        #print Dumper $value;
    #}
    #print "Tabla Impresa.\n" if DEBUG;

    return {'tabla' => %tablaNodos};
}

#   Inicializa las funciones del coordinador
sub iniciarCoordinador {
    print "Arrancando el RPC de coordinador ...\n" if DEBUG;

    #   Metodos expuestos por RPC por el coordinador
    my $methods = {
        'coordinador.tabla' => \&tabla,
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
    my $datos  = "2,";  #   2 es el codigo para indicar que un servidor murio
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
sub toTabla {
    my %result;
    %result;
}

#   Transforma el hash de listas con la informacion de los nodos del sistema
#   en un hash de InfoNodo para trabajar localmente con la informacion
sub fromTabla {
    print "FROM TABLA\n";
    my %result;
    while (my($key, $infoO) = each %tablaNodos) {
        print "Entrando:$key";
        print Dumper $infoO;
        my @infoL = ();
        push @infoL, $infoO->nombre;
        push @infoL, $infoO->pid;
        push @infoL, $infoO->estado;
        print "nodo como lista @infoL\n";
        my @array = $infoO->archivos_todos;
        push @infoL, &archivosToList (@array);


        $result{"$key"} = \@infoL;
    }
    print "SALIENDO DE FROM TABLA\n";
    return %result;
}

sub archivosToList {
    print "archivos to list\n";
    my @archivos = @_; 
    my @result;
    foreach (@archivos) {
        my @archivo = ();
        push @archivo, $_->nombre; #  Guardar el nombre 
        push @archivo, &versionesToList ($_->pares_version_cs);
        push @result, @archivo;
    }
    return @result;
}

sub versionesToList {
    print "versiones to list\n";
    my @versiones = @_;
    my @result;
    for my $pair (@versiones) {
        push @result, ($pair->[0], $pair->[1]);
    }
    return @result;
}

############
#   Main   #
############


#   Consultar al dns quien es el coordinador
$coord = &getCoord();

#   En caso de que seamos el coordinador 
if ($coord eq $hostname) {
    #push @threads, threads->new(\&iniciarCoordinador);
    threads->new(\&iniciarCoordinador)->detach;
}

#   Enviar a todos el hostname y pid. 
&notificar() unless $coord eq $hostname;
$coord eq $hostname ? &agregarServidor($hostname, $my_pid) : &getTabla();

#@values = values %tablaNodos;
#print "Imprimiendo tabla..\n";
#print while ($_ = $tablaNodos->pop);
#print $_->nombre foreach @values;

if ($coord eq $hostname) {
    #threads->new(\&chequearReplicas)->detach;
} else {
    threads->new(\&chequearCoord)->detach;
}

#   Inicia la ejecucion normal del servidor replica 
&escuchar();

#push @threads, threads->new(\&escuchar);
#push @threads, threads->new(\&chequearCoord);

#foreach (@threads) {
    #$_->join;
#}
