use lib qw(.);
use lib qw(./lib/perl5/site_perl/5.12.4/);
use lib qw(./lib/lib/perl5/site_perl/5.12.4);
#use lib qw(./lib/lib/perl5/site_perl/5.12.4/darwin-thread-multi-2level);
use utf8;
use strict;
use threads;
use threads::shared;

use IO::Socket::Multicast;
use IO::Socket::PortState qw(check_ports);
use Frontier::Client;
use Frontier::Daemon;
use RPC::XML;
use Net::Ping;
use Data::Dumper;
use XML::Dumper;

use Archivo;
use InfoNodo;

use constant LOG            => 1;
use constant DEBUG          => 1;
use constant MC_DESTINATION => '226.1.1.4:2000';
use constant MC_GROUP       => '226.1.1.4';
use constant MC_PORT        => '2000';
use constant DNS_URL        => 'stealth.ldc.usb.ve';
use constant DNS_PORT       => '8083';
use constant COORD_RPC_PORT => '8081';

sub getTabla {
    my $server_url = "http://localhost:" . COORD_RPC_PORT . '/RPC2';
    my $server = Frontier::Client->new(url => $server_url);

    my $result = $server->call('coordinador.tabla');
    my $tablaXML = $result->{'tabla'};
    print  $tablaXML;

    #print "IMPRIMIENDO LO QUE ME LLEGO\n";
    #while(my($key,$value) = each %tablaXML) {
    #    print "$key=>\n";
    #    my $nodo = eval $value;
    #    print "hola" if (ref($nodo) eq 'InfoNodo');
    #}
    #print "TABLA IMPRESA LO QUE ME LLEGO\n";
    1;
}

&getTabla();
