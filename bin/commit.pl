use Getopt::Std;
use Frontier::Client;
use Net::SFTP::Foreign;
use constant LOG            => 1;
use constant DEBUG          => 1;
use constant MC_DESTINATION => '226.1.1.4:2000';
use constant MC_GROUP       => '226.1.1.4';
use constant MC_PORT        => '2000';
use constant DNS_URL        => 'titan.ldc.usb.ve';
use constant DNS_PORT       => '8083';
use constant COORD_RPC_PORT => '8081';

my $coord;
my $archivo;
my $user;

sub getCoord {
    print "Contactando al DNS para saber el estado del coordinador...\n" if DEBUG;
    my $server_url = 'http://' . DNS_URL . ':' . DNS_PORT . '/RPC2';
    my $server = Frontier::Client->new(url => $server_url, use_objects => 0);
    my $result = $server->call('dns.coordinador');
    my $aux = $result->{'coordinador'};
    chomp($aux);
    print "El coordinador es: $aux\n" if DEBUG;
    return $aux;
}

sub commit {
    my $archivo = shift;
    my $sftp = Net::SFTP::Foreign->new(host=>$coord, user=>$user);
    $sftp->put("$archivo","/tmp/$archivo");
    my $server_url = "http://$coord:" . COORD_RPC_PORT . '/RPC2';
    my $server = Frontier::Client->new(url => $server_url);
    my $result = $server->call('coordinador.clienteCommit',$archivo);
    my $mensaje = $result->{'clienteCommit'};
    print $mensaje . "\n";
}

sub uso{
    print STDERR << "EOF";

    Commit:
    uso: $0 [-hu] [-f archivo]

    -h          : Ayuda
    -u          : Usuario
    -f archivo  : Archivo a realizar commit

    ejemplo: $0 -f arhcivo.txt
EOF
        exit;
    }

# Main

my $opt_string = 'hf:u:';

getopts( "$opt_string", \%opt ) or &uso();
&uso() if $opt{h};
$user = $opt{u};
$archivo = $opt{f};

$coord = &getCoord;
&commit($archivo);




  
