#!/usr/bin/perl

package Archivo;
use utf8;
use Moose;

use overload 
    q("") => sub {
                my $this = shift;
                my $imp = "";
                $imp .= $this->nombre() . ',';
                for my $pair ($this->pares_version_cs()) {
                    $imp .= $pair->[0] . ',';
                    $imp .= $pair->[1] . ',';
                }
                $imp .= '#';
                return $imp };

has 'nombre'  => (
    isa => 'Str',
    is => 'rw',
    traits => ['String'],
    default => q{},
);
has 'version' => (
    traits => ['Hash'],
    is => 'rw',
    isa => 'HashRef[Str]',
    default => sub { {} },
    handles => {
        agregar_version  => 'set',
        get_version  => 'get',
        contar_versiones => 'count',
        pares_version_cs => 'kv',
    });

__PACKAGE__->meta->make_immutable;

1;
