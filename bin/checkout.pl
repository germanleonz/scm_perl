#!/usr/bin/perl
#   Checkout descarga todos los archivos de un proyecto en la carpeta proyecto

use strict;
use Getopt::Std;
use Frontier::Client;
use Net::SFTP::Foreign;
use constant LOG            => 1;
use constant DEBUG          => 1;
use constant DNS_URL        => 'titan.ldc.usb.ve';
use constant DNS_PORT       => '8083';
use constant COORD_RPC_PORT => '8081';

my $coord;
my $usuario;
my $nombre_proyecto;

# Main
my $opt_string = 'h:u:p:';
my %opt;

getopts("$opt_string", \%opt) or &uso();
&uso() if $opt{h};
$usuario = $opt{u} || `whoami`;
chomp($usuario);
$nombre_proyecto = $opt{p};


if (-d $nombre_proyecto) {
    print "Abortando. El directorio ya existe localmente. Podrian haber conflictos\n";
} else {
    $coord = &getCoord;
    print "usuario: $usuario\n";
    print "nombre proyecto: $nombre_proyecto\n";
    &checkout($nombre_proyecto);
}

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
sub checkout {
    my $nombre_proyecto = shift;

    my $server_url = "http://$coord:" . COORD_RPC_PORT . '/RPC2';
    my $server = Frontier::Client->new(url => $server_url);
    my $result = $server->call('coordinador.clienteCheckout', $usuario, $nombre_proyecto);

    my $nombres_aux = $result->{'clienteCheckout'};
    my @nombres_archivos = split('&',$nombres_aux);
    print "$_\n" foreach(@nombres_archivos);
    mkdir $nombre_proyecto;
    my $sftp = Net::SFTP::Foreign->new(host=>$coord, user=>$usuario);
    foreach (@nombres_archivos) {
        $sftp->get("/tmp/$_", "$nombre_proyecto/$_") if $sftp;
    }
}

#
sub uso {
    print STDERR << "EOF";

    Checkout:
    uso: $0 [-h] | [-u usuario] [-p proyecto] 

    -h          : Ayuda
    -u usuario  : Usuario
    -p proyecto : Proyecto

    ejemplo: $0 -u usuario -p proyecto
EOF
        exit;
}
