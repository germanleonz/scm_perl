#!/usr/bin/perl
use lib qw(.);
use lib qw(./lib/perl5/site_perl/5.12.4/);  use strict;
use lib qw(./lib/lib/perl5/site_perl/5.12.4);
use Data::Dumper;
use Archivo;
use InfoNodo;
use diagnostics;
use Frontier::Client;
use Frontier::Daemon;
use constant LOG            => 1;
use constant DEBUG          => 1;
use constant MC_DESTINATION => '226.1.1.4:2000';
use constant MC_GROUP       => '226.1.1.4';
use constant MC_PORT        => '2000';
use constant DNS_URL        => 'stealth.ldc.usb.ve';
use constant DNS_PORT       => '8083';
use constant COORD_RPC_PORT => '8081';

my $archivo1 = Archivo->new('nombre' => 'archivo 1');
$archivo1->agregar_version('version1' => 'asdjasd', 'version2' => 'asdfasdf');

my $archivo3 = Archivo->new('nombre' => 'archivo 3');
$archivo3->agregar_version('version1' => 'asdsd', 'version2' => 'sdf');

my $archivo4 = Archivo->new('nombre' => 'archivo 4');
$archivo4->agregar_version('version1' => 'djasd', 'version2' => 'fasdf');

my $nodo1 = InfoNodo->new(
    'nombre' => "nodo 1",
    'pid' => "123",
    'estado' => "5",
);
#$nodo1->agregar_archivo($archivo1, $archivo3);


my $nodo2 = InfoNodo->new(
    'nombre' => "nodo 2",
    'pid' => "160",
    'estado' => "2",
);
#$nodo2->agregar_archivo($archivo4);

my %tablaNodos = (
    "123" => $nodo1,
    "160" => $nodo2,
);

print "COMENZANDO\n";
print Dumper \%tablaNodos;
my $tablaComoStr = &fromTabla2Str();
print Dumper $tablaComoStr;
my %tablaNodos2 = &fromStr2Tabla($tablaComoStr);
print Dumper \%tablaNodos2;
print "FIN\n";

sub fromTabla2Str {
    my $string = "";
    foreach (values %tablaNodos) {
        $string .= $_;
    }
    return $string;
}


sub fromStr2Tabla {
    my $tablaStr = shift;
    my %result;
    my @arrayIN = split ('&', $tablaStr); 
    foreach (@arrayIN) {
        my @attr = split ('\#', $_);
        my @nep = split (',', shift @attr);
        my $nombre = shift @nep;
        my $pid    = shift @nep;
        my $estado = shift @nep;
        my $nodo = InfoNodo->new(
            'nombre' => $nombre,
            'pid'    => $pid,
            'estado' => $estado,
        );
        #  Agregando archivos
        foreach (@attr) {
            my @archivoArray = split (',', $_);
            my $nombre_archivo = shift @archivoArray;
            my $archivo = Archivo->new('nombre' => $nombre_archivo);
            while (@archivoArray > 0) {
                my $version = shift @archivoArray;
                my $checksum = shift @archivoArray;
                $archivo->agregar_version(
                    $version => $checksum,
                );
            }
            $nodo->agregar_archivo($archivo);
        }
        $result{$pid} = $nodo;
    }
    %result;
}

#sub tabla {
    #return {'tabla' => %tablaNodos}
#}

 #my $methods = {
             #'coordinador.tabla' => \&tabla,
             #};
#Frontier::Daemon->new(LocalPort => COORD_RPC_PORT, methods => $methods, use_objects => 1)
        #or die "No se pudo iniciar el servidor RPC: $!";
