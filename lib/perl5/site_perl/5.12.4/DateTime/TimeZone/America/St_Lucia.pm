# This file is auto-generated by the Perl DateTime Suite time zone
# code generator (0.07) This code generator comes with the
# DateTime::TimeZone module distribution in the tools/ directory

#
# Generated from /tmp/ggU06B80sE/northamerica.  Olson data version 2013c
#
# Do not edit this file directly.
#
package DateTime::TimeZone::America::St_Lucia;
{
  $DateTime::TimeZone::America::St_Lucia::VERSION = '1.59';
}

use strict;

use Class::Singleton 1.03;
use DateTime::TimeZone;
use DateTime::TimeZone::OlsonDB;

@DateTime::TimeZone::America::St_Lucia::ISA = ( 'Class::Singleton', 'DateTime::TimeZone' );

my $spans =
[
    [
DateTime::TimeZone::NEG_INFINITY, #    utc_start
59611176240, #      utc_end 1890-01-01 04:04:00 (Wed)
DateTime::TimeZone::NEG_INFINITY, #  local_start
59611161600, #    local_end 1890-01-01 00:00:00 (Wed)
-14640,
0,
'LMT',
    ],
    [
59611176240, #    utc_start 1890-01-01 04:04:00 (Wed)
60305313840, #      utc_end 1912-01-01 04:04:00 (Mon)
59611161600, #  local_start 1890-01-01 00:00:00 (Wed)
60305299200, #    local_end 1912-01-01 00:00:00 (Mon)
-14640,
0,
'CMT',
    ],
    [
60305313840, #    utc_start 1912-01-01 04:04:00 (Mon)
DateTime::TimeZone::INFINITY, #      utc_end
60305299440, #  local_start 1912-01-01 00:04:00 (Mon)
DateTime::TimeZone::INFINITY, #    local_end
-14400,
0,
'AST',
    ],
];

sub olson_version { '2013c' }

sub has_dst_changes { 0 }

sub _max_year { 2023 }

sub _new_instance
{
    return shift->_init( @_, spans => $spans );
}



1;

