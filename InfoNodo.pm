#!/usr/bin/perl

package InfoNodo;
use utf8;
use Moose;
use Archivo;

use overload 
    q("") => sub {
                my $this = shift;
                my $imp = "";
                $imp .= $this->nombre();
                $imp .= $this->pid() . ',';
                $imp .= $this->estado() . ',';
                #my @algo = $this->all_options;
                $imp .= $this->archivos_todos;
                return $imp };

has 'nombre'  => ( isa => 'Str', is => 'rw');
has 'pid'     => ( isa => 'Num', is => 'rw');
has 'estado'  => ( isa => 'Num', is => 'rw');
has 'archivo' => (
    traits => ['Array'],
    is => 'rw',
    isa => 'ArrayRef[Archivo]',
    default => sub { [] },
    handles => {
        archivos_todos  => 'elements',
        agregar_archivo => 'push',
        contar_archivos => 'count',
    });

__PACKAGE__->meta->make_immutable;

1;
