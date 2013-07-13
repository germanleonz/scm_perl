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

my @enviar;

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
$nodo1->agregar_archivo($archivo1, $archivo3);


my $nodo2 = InfoNodo->new(
    'nombre' => "nodo 2",
    'pid' => "160",
    'estado' => "2",
);
$nodo2->agregar_archivo($archivo4);

my %tablaNodos = (
    "123" => $nodo1,
    "160" => $nodo2,
);

#while (my($key,$value) = each %tablaNodos) {
#      print "$key =>";
#      print Dumper $value;
#}

print "LISTO\n";

my %tablaComoLista = &fromTabla();

#while (my($key,$value) = each %tablaComoLista) {
#      print "$key =>";
#      print Dumper $value;
#}

sub fromTabla {
    my %result;
    while (my($key, $infoO) = each %tablaNodos) {
        my @infoL = ();
        push @infoL, $infoO->nombre;
        push @infoL, $infoO->pid;
        push @infoL, $infoO->estado;
        my @array = $infoO->archivos_todos;
        push @infoL, &archivosToList (@array);

        $result{"$key"} = \@infoL;
    }
    return %result;
}

sub archivosToList {
    my @archivos = @_; 
    my @result;
    foreach (@archivos) {
        my @archivo = ();
        push @archivo, $_->nombre; #  Guardar el nombre 
        push @archivo, &versionesToList ($_->pares_version_cs);
        push @result, @archivo;
    }
    return @result;
}

sub versionesToList {
    my @versiones = @_;
    my @result;
    for my $pair (@versiones) {
        push @result, ($pair->[0], $pair->[1]);
    }
    return @result;
}



use XML::Dumper;
 my $dump = new XML::Dumper;

use XML::Simple;
my $xs = new XML::Simple();

my $enviar = "";
while (my($key,$value) = each %tablaNodos) {
    print $value;
    print $value->archivos_todos();

}
print "$enviar\n";
sub tabla{
    while (my($key,$value) = each %tablaNodos) {
    my $datos = Data::Dumper->Dump([$value], [qw /InfoNodo_value_evaled/ ]) ;

    return {'tabla' => $enviar}
    }
}
 my $methods = {
             'coordinador.tabla' => \&tabla,
             };
Frontier::Daemon->new(LocalPort => COORD_RPC_PORT, methods => $methods, use_objects => 1)
        or die "No se pudo iniciar el servidor RPC: $!";
