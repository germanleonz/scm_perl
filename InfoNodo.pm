#!/usr/bin/perl

package InfoNodo;
use Moose;
use Archivo;

use overload 
    q("") => sub { return shift->nombre() };

has 'nombre'  => ( isa => 'Str', is => 'rw');
has 'pid'     => ( isa => 'Num', is => 'rw');
has 'archivo' => (
    traits => ['Array'],
    is => 'ro',
    isa => 'ArrayRef[Archivo]',
    default => sub { [] },
    handles => {
        all_options   => 'elements',
        agregar_archivo    => 'push',
        contar_archivos => 'count',
    });
has 'estado'  => ( isa => 'Num', is => 'rw');

__PACKAGE__->meta->make_immutable;

1;
