# This file is auto-generated by the Perl DateTime Suite time zone
# code generator (0.07) This code generator comes with the
# DateTime::TimeZone module distribution in the tools/ directory

#
# Generated from /tmp/ggU06B80sE/asia.  Olson data version 2013c
#
# Do not edit this file directly.
#
package DateTime::TimeZone::Asia::Muscat;
{
  $DateTime::TimeZone::Asia::Muscat::VERSION = '1.59';
}

use strict;

use Class::Singleton 1.03;
use DateTime::TimeZone;
use DateTime::TimeZone::OlsonDB;

@DateTime::TimeZone::Asia::Muscat::ISA = ( 'Class::Singleton', 'DateTime::TimeZone' );

my $spans =
[
    [
DateTime::TimeZone::NEG_INFINITY, #    utc_start
60557745936, #      utc_end 1919-12-31 20:05:36 (Wed)
DateTime::TimeZone::NEG_INFINITY, #  local_start
60557760000, #    local_end 1920-01-01 00:00:00 (Thu)
14064,
0,
'LMT',
    ],
    [
60557745936, #    utc_start 1919-12-31 20:05:36 (Wed)
DateTime::TimeZone::INFINITY, #      utc_end
60557760336, #  local_start 1920-01-01 00:05:36 (Thu)
DateTime::TimeZone::INFINITY, #    local_end
14400,
0,
'GST',
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

