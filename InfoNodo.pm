#!/usr/bin/perl
#   Clase que representa la informacion de un nodo del sistema. Esta incluye
#   un nombre de host, pid del proceso que corre la replica, un contador que
#   representa el estado del servidor y un hash con la informacion de los
#   archivos que maneja dicho nodo

package InfoNodo;
use utf8;
use Moose;
use Archivo;

use overload 
q("") => sub {
    my $this = shift;
    my $imp = "";
    $imp .= $this->nombre() . ',';
    $imp .= $this->pid() . ',';
    $imp .= $this->estado() . '#';
    my @aux;
    if ($this->contar_archivos > 0) {
        @aux = $this->archivos_todos();
        $imp .= $_ foreach @aux;
    } else {
        $imp .= '#';
    }
    $imp .= '&';
    return $imp };

has 'nombre'  => ( isa => 'Str', is => 'rw');
has 'pid'     => ( isa => 'Num', is => 'rw');
has 'estado'  => (
    traits  => ['Counter'],
    isa     => 'Num',
    is      => 'rw',
    default => 5,
    handles => {
        aumentar_contador => 'inc',
        bajar_contador    => 'dec',
        reset_contador    => 'reset',
    },
);
has 'archivo' => (
    traits => ['Hash'],
    is => 'rw',
    isa => 'HashRef[Archivo]',
    default => sub { {} },
    handles => {
        archivos_todos  => 'kv',
        agregar_archivo => 'set',
        buscar_archivo  => 'get',
        contar_archivos => 'count',
        tiene_archivo   => 'exists',
    }
);

__PACKAGE__->meta->make_immutable;

1;
