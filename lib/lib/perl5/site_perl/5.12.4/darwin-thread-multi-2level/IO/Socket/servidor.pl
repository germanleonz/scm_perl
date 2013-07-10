use lib qw(./lib/);
use IO::Socket::Multicast;
use tabla;

my $object = new tabla( "Mohammad", "Saleem", 23234345);


use constant DESTINATION => '226.1.1.2:2000'; 
my $sock = IO::Socket::Multicast->new(Proto=>'udp',PeerAddr=>DESTINATION);
my $message = "host1 ++ host2";
$message .= "\n" . `who`;
$sock->send($message) || die "Couldn't send: $!";


