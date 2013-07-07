#!/usr/bin/perl

#use lib qw(./lib/perl5/site_perl/5.12.4/);
use lib qw(./lib/lib/perl5/site_perl/5.12.4);
use lib qw(./lib/lib/perl5/site_perl/5.12.4/darwin-thread-multi-2level);
use strict;
use diagnostics;
use threads;
use IO::Socket::Multicast;
use Hash::PriorityQueue;
use Frontier::Client;
use Frontier::Daemon;
use RPC::XML;
use Net::Ping;
#use Switch;

use Archivo;
use InfoNodo;

use constant DEBUG          => 1;
use constant MY_URL         => '192.168.1.111';
use constant MC_DESTINATION => '226.1.1.4:2000';
use constant MC_GROUP       => '226.1.1.4';
use constant MC_PORT        => '2000';
use constant DNS_URL        => '192.168.1.111';
use constant DNS_PORT       => '8083';
use constant COORD_RPC_PORT => '8081';

my $coord = "";
my $coordinadores = Hash::PriorityQueue->new();
my $tablaNodos = Hash::PriorityQueue->new();
my $hostname = `hostname`;
my $pid = getppid;
chomp($pid);
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
    $coord = $result->{'coordinador'};
    chomp($coord);
    print "El coordinador es: $coord \n" if DEBUG;
}

sub setCoord {
    print "Cambiando de coordinador...\n" if DEBUG;
    my $coordOld = $coord;
    $coord = $coordinadores->pop;
    if ($coord eq $coordOld) {
        my $server_url = 'http://' . DNS_URL . ':' . DNS_PORT . '/RPC2';
        my $server = Frontier::Client->new(url => $server_url, use_objects => 0);
        my $arg = $server->string($hostname);
        my $result = $server->call('dns.actualizar', $arg);
    }
}

sub chequearCoord {
    while (1) {
        next if ($coord eq "");
        #print "Revisando coord $coord\n" if DEBUG;
        my $timeout = 7;
        &setCoord() if ! pingecho($coord, $timeout);
        #print "Coord $coord\n" if DEBUG;
    }
}

# Esta rutina notifica a todos los servidores la incorporacion de este servidor
# replica enviando con multicast su hostname y pid
sub notificar {
    print "Notificando mi informacion al grupo multicast\n" if DEBUG;
    my $socket = IO::Socket::Multicast->new(PeerAddr=>MC_DESTINATION);
    my $datos  = "1,";
    $datos .= $hostname . ",";
    $datos .= $pid . ",";
    $socket->send($datos) || die "No se pudo notificar al grupo: $!";
    print "Notificacion enviada al grupo multicast\n" if DEBUG;
}

# Esta rutina escucha multicast y dependiendo del codigo que reciba ejecuta la
# rutina correspondiente
sub escuchar {
    my $sock = IO::Socket::Multicast->new(LocalPort=>MC_PORT);
    $sock->mcast_add(MC_GROUP) || die "No se pudo asociar al grupo multicast: $!\n"; 

    while (1) {
        my $data;
        next unless $sock->recv($data,1024);
        my @datos = split(',',$data);

        &agregarServidor($datos[1], $datos[2]) if ($datos[0] eq "1");
    }
}

# Esta rutina se encarga de agregar un nuevo servidor a las tabla 
sub agregarServidor {
    my $servidor = shift;
    my $pid      = shift;

    print "Agregando:$servidor:$pid\n" if DEBUG;

    #   Agregamos la informacion del nuevo nodo a la tabla
    my $nuevo = InfoNodo->new(nombre=>$servidor,pid=>$pid);
    $tablaNodos->insert($nuevo,$servidor);

    $coordinadores->insert($servidor, $servidor);
}

# RPC Cliente
sub get_tabla {
    my $server_url = "http://$coord:" . COORD_RPC_PORT . '/RPC2';
    my $server = Frontier::Client->new(url => $server_url);
    my $result = $server->call('coordinador.tabla');
    my $tablaNodos = $result->{'tabla'};

    #&agregarServidor($hostname,$pid) unless $tablaNodos{$hostname};
}

#
#   Rutinas propias del coordinador
#

# Metodos RPC expuestos por el coordinador 
sub tabla {
    return {'tabla'=> $tablaNodos};
}

# Inicializa las funciones del coordinador
sub iniciarCoordinador {
    print "Arrancando el RPC de coordinador ...\n" if DEBUG;

    #   Metodos expuestos por RPC por el coordinador
    my $methods = {
        'coordinador.tabla' => \&tabla,
    };
    Frontier::Daemon->new(LocalPort => COORD_RPC_PORT, methods => $methods)
        or die "No se pudo iniciar el servidor RPC: $!";
}

# Main()

# Consultar al dns el coordinador
&getCoord();

# En caso de que seamos el coordinador 
my $tRPCCoord;
print "coord:$coord\n" if DEBUG;
print "hostname:$hostname\n" if DEBUG;
if ($coord eq $hostname) {
    $tRPCCoord = threads->new(\&iniciarCoordinador);
}

# Enviar a todos el hostname y pid
&notificar() unless $coord eq $hostname;
$coord eq $hostname ? &agregarServidor($hostname, $pid) : &get_tabla();

#@values = values %tablaNodos;
#print "Imprimiendo tabla..\n";
#print while ($_ = $tablaNodos->pop);
#print $_->nombre foreach @values;

#   Inicia la ejecucion normal del servidor replica 
#&escuchar();

my $tCoord = threads->new(\&chequearCoord);
my $rs = $tCoord->join();
my $rs2 = $tRPCCoord->join() if defined $tRPCCoord;
