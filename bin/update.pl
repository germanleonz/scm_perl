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

my $coord;
my $archivo;
my $usuario;
my $proyecto;

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

sub pull {
    my $archivo = shift;
    my $server_url = "http://$coord:" . COORD_RPC_PORT . '/RPC2';
    my $server = Frontier::Client->new(url => $server_url);
    my $result = $server->call('coordinador.clientePull',$usuario,$proyecto,$archivo);
    my $mensaje = $result->{'clientePull'};
    my $sftp = Net::SFTP::Foreign->new(host=>$coord, user=>$usuario);

    print "Recibiendo archivo $archivo $usuario $coord \n" if DEBUG;
    print Dumper $sftp;
    $sftp->get("/tmp/$archivo","./$archivo") unless $sftp->error;
}

sub uso{
    print STDERR << "EOF";

    Commit:
    uso: $0 [-hu] [-f archivo]

    -h          : Ayuda
    -u          : Usuario
    -p          : Proyecto
    -f archivo  : Archivo a realizar commit

    ejemplo: $0 -f arhcivo.txt
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
&pull($archivo);




  
