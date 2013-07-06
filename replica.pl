use lib qw(./lib/perl5/site_perl/5.12.4/);
use diagnostics;
use Frontier::Client;
use  RPC::XML;
use RPC::XML::Client;
use threads;
use Net::Ping;
use Switch;
$coord = "";

sub getCoord{
  my $server_url = 'http://qirtaiba.ldc.usb.ve:8083/RPC2';
  $server = Frontier::Client->new(url => $server_url, use_objects => 0);
  my  $arg = $server->string(`hostname`);
  my $result = $server->call('dns.coordinador', $arg);
  $coord = $result->{'coordinador'};
  chomp($coord);
  print "El coordinador es: $coord \n";
}

sub setCoord{
  print "entre\n";
  my $coordOld = $coord;
  &getCoord();
  if ($coord eq $coordOld){
    my $server_url = 'http://qirtaiba.ldc.usb.ve:8083/RPC2';
    $server = Frontier::Client->new(url => $server_url, use_objects => 0);
    my $arg = $server->string(`hostname`);
    my $result = $server->call('dns.actualizar', $arg);
  }
}
sub checkCoord{
  while (1){
    next if ($coord eq "");
    print "Revisando coord $coord\n";
    $timeout = 5;
    &setCoord() if ! pingecho($coord, $timeout);
    print "Coord $coord\n"
  }
}

# Main()
&getCoord();
print $coord;
my $tCoord = threads->new(\&checkCoord);
my $rs = $tCoord->join();

