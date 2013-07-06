#!/usr/bin/perl
package InfoNodo;
use Moose;
use namespace::autoclean;

has 'nombre'  => ( isa => 'Str', is => 'rw');
has 'pid'     => ( isa => 'Num', is => 'rw');
has 'archivo' => (
    traits => ['Array'],
    is => 'ro',
    isa => 'ArrayRef[Str]',
    default => sub { [] },
    handles => {
        all_options   => 'elements',
        add_option    => 'push',
        count_options => 'count',
    });
has 'estado'  => ( isa => 'Num', is => 'rw');

__PACKAGE__->meta->make_immutable;

1;
