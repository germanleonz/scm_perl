# Servidor de nombre de dominio
use lib qw(./lib/perl5/site_perl/5.12.4/);
use Frontier::Client;
use Frontier::Daemon;

$coord = "";
sub coordinador{
  $pregunta = @_[0] ;
  if ( $coord eq ""){
    print "Chequeando\n";
    $coord = $pregunta;
    print "Coord: $coord\n";
  }
  return  {'coordinador' => $coord};
}

$methods = {'dns.coordinador' => \&coordinador};
Frontier::Daemon->new(LocalPort => 8083, methods => $methods, use_objects => 0)
  or die "Couldn't start HTTP server: $!";

