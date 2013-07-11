#!/usr/bin/perl

package InfoNodo;
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
                $imp .= $this->all_options;
                return $imp };

has 'nombre'  => ( isa => 'Str', is => 'rw');
has 'pid'     => ( isa => 'Num', is => 'rw');
has 'estado'  => ( isa => 'Num', is => 'rw');
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

__PACKAGE__->meta->make_immutable;

1;
