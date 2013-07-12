#!/usr/bin/perl
# Servidor de nombre de dominio

use utf8;
use strict;

use lib qw(.);
#use lib qw(./lib/lib/perl5/site_perl/5.12.4);
use Frontier::Daemon;
use Thread::Semaphore;

use constant DEBUG    => 1;
use constant DNS_ADDR => 'sheena.ldc.usb.ve';
use constant DNS_PORT => '8083';

my $semaphore = Thread::Semaphore->new(1);
my $coord = "";

#   Este metodo lo utilizan todos los servidores replicas para saber
#   quien es el coordinador. La primera vez que alguien lo llame ese
#   nodo sera el coordinador
sub coordinador {
    $semaphore->down(1);   
    my $pregunta = shift;
    if ($coord eq "") {
        print "Inicializando el coordinador...\n" if DEBUG;
        $coord = $pregunta;
    }
    print "El coordinador es: $coord\n" if DEBUG;
    $semaphore->up(1);   
    return {'coordinador' => $coord};
}

#   Este metodo un nodo que haya decidido que el debe ser el proximo 
#   coordinador
sub actualizar {
    $semaphore->down(1);   
    $coord = shift;
    print "Nuevo coordinador: $coord\n" if DEBUG;
    $semaphore->up(1);
} 

#   Programa principal. Se escuchan futuras llamadas a metodos RPC
my $methods = {
    'dns.coordinador' => \&coordinador,
    'dns.actualizar'  => \&actualizar,
};

print "Inicializando servicios de DNS...\n" if DEBUG;
Frontier::Daemon->new(
    LocalAddr   => DNS_ADDR,
    LocalPort   => DNS_PORT,
    methods     => $methods,
    )
    or die "No se pudo inicializar el servidor DNS: $!";
