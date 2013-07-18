#!/usr/bin/perl
#   Checkout descarga todos los archivos de un proyecto en la carpeta proyecto

use strict;
use Getopt::Std;
use Frontier::Client;
use Net::SFTP::Foreign;
use constant LOG            => 1;
use constant DEBUG          => 1;
use constant DNS_URL        => 'karama.ldc.usb.ve';
use constant DNS_PORT       => '8083';
use constant COORD_RPC_PORT => '8081';

my $coord;
my $usuario;
my $nombre_proyecto;
my $invitado;

# Main
my $opt_string = 'h:u:p:i:';
my %opt;

getopts("$opt_string", \%opt) or &uso();
&uso() if $opt{h};
$usuario = $opt{u} || `whoami`;
chomp($usuario);
$nombre_proyecto = $opt{p};
$invitado = $opt{i};

$coord = &getCoord();
&share();

#
sub getCoord {
    print "Conectando ...\n" if DEBUG;
    my $server_url = 'http://' . DNS_URL . ':' . DNS_PORT . '/RPC2';
    my $server = Frontier::Client->new(url => $server_url, use_objects => 0);
    my $result = $server->call('dns.coordinador');
    my $aux = $result->{'coordinador'};
    chomp($aux);
    return $aux;
}

#   Solicita al sistema la realizacion de un commit
sub share {
    my $nombre_proyecto = shift;

    my $server_url = "http://$coord:" . COORD_RPC_PORT . '/RPC2';
    my $server = Frontier::Client->new(url => $server_url);
    my $result = $server->call('coordinador.clienteShare', $usuario, $nombre_proyecto);

    my $nombres_aux = $result->{'clienteShare'};
}

#
sub uso {
    print STDERR << "EOF";

    Checkout:
    uso: $0 [-h] | [-u usuario] [-p proyecto] 

    -h          : Ayuda
    -u usuario  : Usuario
    -p proyecto : Proyecto
    -i invitado : Usuario a compartir

    ejemplo: $0 -u usuario -p proyecto
EOF
        exit;
}
