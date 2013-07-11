#!/usr/bin/perl

package Archivo;
use Moose;

use overload 
    q("") => sub {
                my $this = shift;
                my $imp = "";
                $imp .= $this->nombre() . ',';
                #my @algo = $this->option_pairs;
                $imp .= $this->option_pairs;
                return $imp };

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
        option_pairs => 'kv',
    });

__PACKAGE__->meta->make_immutable;

1;
