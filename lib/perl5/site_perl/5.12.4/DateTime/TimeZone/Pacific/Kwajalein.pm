# This file is auto-generated by the Perl DateTime Suite time zone
# code generator (0.07) This code generator comes with the
# DateTime::TimeZone module distribution in the tools/ directory

#
# Generated from /tmp/ggU06B80sE/australasia.  Olson data version 2013c
#
# Do not edit this file directly.
#
package DateTime::TimeZone::Pacific::Kwajalein;
{
  $DateTime::TimeZone::Pacific::Kwajalein::VERSION = '1.59';
}

use strict;

use Class::Singleton 1.03;
use DateTime::TimeZone;
use DateTime::TimeZone::OlsonDB;

@DateTime::TimeZone::Pacific::Kwajalein::ISA = ( 'Class::Singleton', 'DateTime::TimeZone' );

my $spans =
[
    [
DateTime::TimeZone::NEG_INFINITY, #    utc_start
59958190240, #      utc_end 1900-12-31 12:50:40 (Mon)
DateTime::TimeZone::NEG_INFINITY, #  local_start
59958230400, #    local_end 1901-01-01 00:00:00 (Tue)
40160,
0,
'LMT',
    ],
    [
59958190240, #    utc_start 1900-12-31 12:50:40 (Mon)
62127694800, #      utc_end 1969-09-30 13:00:00 (Tue)
59958229840, #  local_start 1900-12-31 23:50:40 (Mon)
62127734400, #    local_end 1969-10-01 00:00:00 (Wed)
39600,
0,
'MHT',
    ],
    [
62127694800, #    utc_start 1969-09-30 13:00:00 (Tue)
62881531200, #      utc_end 1993-08-20 12:00:00 (Fri)
62127651600, #  local_start 1969-09-30 01:00:00 (Tue)
62881488000, #    local_end 1993-08-20 00:00:00 (Fri)
-43200,
0,
'KWAT',
    ],
    [
62881531200, #    utc_start 1993-08-20 12:00:00 (Fri)
DateTime::TimeZone::INFINITY, #      utc_end
62881574400, #  local_start 1993-08-21 00:00:00 (Sat)
DateTime::TimeZone::INFINITY, #    local_end
43200,
0,
'MHT',
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

