use lib qw(./lib/perl5/site_perl/5.12.4/);
use diagnostics;
use threads;
use Frontier::Client;
use Frontier::Daemon;
use RPC::XML;
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

# Esta rutina notifica a todos los servidores la incorporacion de este servidor
# replica enviando con multicas su hostname y pid
sub notificar{
  DESTINATION => '226.1.1.4:2000';
  my $sockF = IO::Socket::Multicast->new(Proto=>'udp',PeerAddr=>DESTINATION);
  $datos  = "1,";
  $datos .= $hostname . ",";
  $datos .= $pid . ",";
  $sockF->send($datos) || die "Couldn't send: $!";
}

# Esta rutina escucha multicast y dependiendo del codigo que reciba ejecuta la
# rutina correspondiente
sub escuchar{
  use constant GROUP => '226.1.1.4';
  use constant PORT  => '2000';

  my $sock = IO::Socket::Multicast->new(Proto=>'udp',LocalPort=>PORT);
  $sock->mcast_add(GROUP) || die "Couldn't set group: $!\n"; 
  next unless $sock->recv($data,1024);
  my @datos = split(',',$data);

  &agregarServidor($datos[1], $datos[2]) if ($datos[0] eq "1");
}

# Esta rutina se encarga de agregar un nuevo servidor a las tabla 
sub agregarServidor{
  my $servidor = shift;
  my $pid = shift;

  my $nuevo = InfoNodo->new(nombre=>$servidor,pid=>$pid);
  $tablaNodos->insert($nuevo,$servidor);

}

# RPC Servidor
{
 sub tabla{
    return {'tabla'=> @tabla};
 }

 $methods = {'coordinador.tabla' => \&tabla};
 Frontier::Daemon->new(LocalPort => 8081, methods => $methods)
    or die "Couldn't start HTTP server: $!";
}

# RPC Cliente
{
  $server_url = 'http://localhost:8081/RPC2';
  $server = Frontier::Client->new(url => $server_url);
  $result = $server->call('coordinador.tabla');
  $tablaNodos = $result->{'tabla'};

  &agregarServidor($hostname,$pid) unless $tablaNodos{$hosname};
}


# Main()

# Obtener Pid del proceso
$pid = getppid;
$hostname = `hostname`;
$tablaNodos = Hash::PriorityQueue->new();
chomp($pid);
chomp($hostname);

# Consultar al dns el coordinador
&getCoord();
print $coord;

# Enviar a todos el hostname y pid
&notificar() unless $coord eq $hostname;
$getTabla()

my $tCoord = threads->new(\&checkCoord);
my $rs = $tCoord->join();

