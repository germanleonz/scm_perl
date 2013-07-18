#!/usr/bin/perl
#   Programa cliente

use strict;
use Getopt::Std;
use Frontier::Client;
use Net::SFTP::Foreign;
use constant LOG            => 1;
use constant DEBUG          => 1;
use constant MC_DESTINATION => '226.1.1.4:2000';
use constant MC_GROUP       => '226.1.1.4';
use constant MC_PORT        => '2000';
use constant DNS_URL        => 'karama.ldc.usb.ve';
use constant DNS_PORT       => '8083';
use constant COORD_RPC_PORT => '8081';
use constant PERM           => '777';

my $coord;
my $archivo;
my $usuario;
my $proyecto;
my %opt;

# Main
my $opt_string = 'hf:u:p:';

getopts("$opt_string", \%opt) or &uso();
&uso() if $opt{h};
$usuario = $opt{u} || `whoami`;
chomp($usuario);
$archivo = $opt{f};
$proyecto = $opt{p};

$coord = &getCoord;
&commit($archivo);

#
sub getCoord {
    print "Conectando ...\n" if DEBUG;
    my $server_url = 'http://' . DNS_URL . ':' . DNS_PORT . '/RPC2';
    my $server     = Frontier::Client->new(url => $server_url, use_objects => 0);
    my $result     = $server->call('dns.coordinador');
    my $aux        = $result->{'coordinador'};
    chomp($aux);
    return $aux;
}

#   Solicita al sistema la realizacion de un commit
sub commit {
    my $archivo = shift;
    my $sftp = Net::SFTP::Foreign->new(host=>$coord, user=>$usuario);
    my $attrs;
    $sftp->mkpath("/tmp/$usuario/");
    $sftp->chmod("/tmp/$usuario/",0777);
    $sftp->put("$archivo","/tmp/$usuario/$archivo");

    my $server_url = "http://$coord:" . COORD_RPC_PORT . '/RPC2';
    my $server     = Frontier::Client->new(url => $server_url);
    my $result     = $server->call('coordinador.clienteCommit',$usuario,$proyecto,$archivo);
    my $mensaje    = $result->{'clienteCommit'};
    print $mensaje . "\n";
}

#
sub uso {
    print STDERR << "EOF";

    Commit:
    uso: $0 [-h] | [-u usuario] [-p proyecto] -f archivo

    -h          : Ayuda
    -u          : Usuario
    -p          : Proyecto
    -f archivo  : Archivo a realizar commit

    ejemplo: $0 -f archivo.txt
EOF
        exit;
    }

# Main

my $opt_string = 'hf:u:p:';

getopts( "$opt_string", \%opt ) or &uso();
&uso() if $opt{h};
$usuario = $opt{u};
$archivo = $opt{f};
$proyecto = $opt{p};

$coord = &getCoord;
&commit($archivo);




  
