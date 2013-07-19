#!/usr/bin/perl
#   Programa cliente

use strict;
use Getopt::Std;
use Frontier::Client;
use Net::SFTP::Foreign;
use Data::Dumper;
use constant LOG            => 1;
use constant DEBUG          => 1;
use constant MC_DESTINATION => '226.1.1.4:2000';
use constant MC_GROUP       => '226.1.1.4';
use constant MC_PORT        => '2000';
use constant DNS_URL        => 'titan.ldc.usb.ve';
use constant DNS_PORT       => '8083';
use constant COORD_RPC_PORT => '8081';
# Main
my $opt_string = 'hf:u:p:';
my %opt;

my $comando = $ARGV[0];
shift @ARGV;
getopts("$opt_string", \%opt) or &uso();
&uso() if $opt{h};
my $usuario = $opt{u} || `whoami`;
chomp($usuario);
my $archivo = $opt{f};
my $proyecto = $opt{p};

my $coord = &getCoord;


if ($opt{p} eq "")  {
  print STDERR << "EOF";
    Es necesario indicar el nombre del proyeto.
EOF
}

if ($comando eq 'commit') {
  if (!exists $opt{f}){
    print STDERR << "EOF";
    Es necesario indicar el nombre del archivo.
EOF
    &usoCommit;
  }
  &usoCommit unless exists $opt{p};
  &commit($archivo);
}
elsif ($comando eq 'checkout') {
  &usoCheckout unless exists $opt{p};
  &checkout($archivo);
}
elsif ($comando eq 'update') {
  if (!exists $opt{f}){
    print STDERR << "EOF";
    Es necesario indicar el nombre del archivo.
EOF
    &usoUpdate;
  }
  &usoUptdate unless exists $opt{p};

  &pull($archivo);
}

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
        $sftp->get("/tmp/$usuario/$_", "$nombre_proyecto/$_") if $sftp;
    }
}
sub pull {
    my $archivo    = shift;
    print "Usuario $usuario\n";
    my $server_url = "http://$coord:" . COORD_RPC_PORT . '/RPC2';
    my $server = Frontier::Client->new(url => $server_url);
    my $result = $server->call('coordinador.clientePull',$usuario,$proyecto,$archivo);
    my $mensaje = $result->{'clientePull'};
    if ($mensaje eq "Archivo $archivo actualizado\n") {
        print "Recibiendo archivo $archivo $usuario $coord \n" if DEBUG;
        my $sftp = Net::SFTP::Foreign->new(host=>$coord, user=>$usuario);
        print "Path /tmp/$usuario/$archivo\n";
        print Dumper $sftp->error;
        $sftp->get("/tmp/$archivo","./$archivo") unless $sftp->error;
    }

    print $mensaje;
}


sub usoUpdate {
    print STDERR << "EOF";

    Pull:
    uso: $0 pull [-hu] [-f archivo] [-p proyecto]

    -h          : Ayuda
    -u          : Usuario
    -p          : Proyecto
    -f archivo  : Archivo para hacer pull

    ejemplo: $0 -f archivo.txt
EOF
        exit;
    }

#
sub usoCheckout {
    print STDERR << "EOF";

    Checkout:
    uso: $0 checkout [-h] | [-u usuario] [-p proyecto] 

    -h          : Ayuda
    -u usuario  : Usuario
    -p proyecto : Proyecto

    ejemplo: $0 -u usuario -p proyecto
EOF
        exit;
}

#
sub usoCommit {
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

sub uso {
  print STDERR << "EOF";
  uso: $0 comando [-h] | [-u usuario] [-p proyecto] [-f archivo]
    -h          : Ayuda
    -u          : Usuario
    -p          : Proyecto
    -f archivo  : Archivo a realizar commit
  
  ejemplo scm commit -u usuario -p proyecto -f archivo
EOF
exit;
}

  
