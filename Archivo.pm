#!/usr/bin/perl

package Archivo;
use Moose;

use overload 
    q("") => sub { return shift->nombre() };

has 'nombre'  => (
    isa => 'Str',
    is => 'rw',
    traits => ['String'],
    default => q{},
);
has 'version' => (
    traits => ['Hash'],
    is => 'ro',
    isa => 'HashRef[Str]',
    default => sub { {} },
    handles => {
        set_option  => 'set',
        get_option  => 'get',
        num_options => 'count',
    });

__PACKAGE__->meta->make_immutable;

1;
