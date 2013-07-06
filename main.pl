#!/usr/bin/perl
use 5.014;

use lib qw(.);
use InfoNodo;
use Archivo;

my $host1 = InfoNodo->new(nombre => "Tabla 1");
my $archivo1 = Archivo->new(nombre => "Archivo 1");
$host1->add_option($archivo1);
my @archivos = $host1->all_options;
my $archivoLeido = $archivos[0];
say "$archivoLeido";
