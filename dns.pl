# Servidor de nombre de dominio
use lib qw(./lib/perl5/site_perl/5.12.4/);
use Frontier::Client;
use Frontier::Daemon;
use Thread::Semaphore;

my $semaphore = Thread::Semaphore->new(1);

$coord = "";
sub coordinador{
  $semaphore->down(1);   
  $pregunta = @_[0] ;
  if ( $coord eq ""){
    print "Chequeando\n";
    $coord = $pregunta;
    print "Coord: $coord\n";
  }
  return  {'coordinador' => $coord};
  $semaphore->up(1);   
}

sub actualizar{
  $semaphore->down(1);   
  $coord = @_[0];
  print "Nuevo coordinador $coord\n";
  $semaphore->up(1);
} 

$methods = {'dns.coordinador' => \&coordinador,
            'dns.actualizar' => \&actualizar};
Frontier::Daemon->new(LocalPort => 8083, methods => $methods, use_objects => 0)
  or die "Couldn't start HTTP server: $!";

