#!/usr/bin/perl
# Servidor de nombre de dominio

use diagnostics;
use strict;

use lib qw(./lib/lib/perl5/site_perl/5.12.4);
use Frontier::Daemon;
use Thread::Semaphore;

use constant DEBUG    => 1;
use constant DNS_ADDR => '192.168.1.111';
use constant DNS_PORT => 8083;

my $semaphore = Thread::Semaphore->new(1);
my $coord = "";

sub coordinador {
  $semaphore->down(1);   
  my $pregunta = shift;
  if ($coord eq "") {
    print "Chequeando\n" if DEBUG;
    $coord = $pregunta;
    print "Coord: $coord\n" if DEBUG;
  }
  $semaphore->up(1);   
  return {'coordinador' => $coord};
}

sub actualizar {
  $semaphore->down(1);   
  $coord = shift;
  print "Nuevo coordinador: $coord\n" if DEBUG;
  $semaphore->up(1);
} 

#   Main
my $methods = {
    'dns.coordinador' => \&coordinador,
    'dns.actualizar'  => \&actualizar,
};

Frontier::Daemon->new(
    LocalAddr   => DNS_ADDR,
    LocalPort   => DNS_PORT,
    methods     => $methods,
    use_objects => 0)
  or die "No se pudo inicializar el servidor DNS: $!";

