#!/usr/bin/perl
package Archivo;
use Moose;
use namespace::autoclean;

has 'nombre'  => ( isa => 'Str', is => 'rw');
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

