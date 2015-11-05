# /*
#  * Win32Helper.pm - a plugin helper module for munin-node-win32-cygwin
#  *
#  * Copyright (c) 2015 John Vinopal
#  * Licensed under the MIT license.
#  */
package Win32Helper;
use strict;
use warnings;
use Data::Dumper;

require Win32::OLE;
Win32::OLE->Option(Warn => 2);

use Exporter;
our @ISA     = qw(Exporter);
our @EXPORT  = qw(getWin32Props getRawWin32Props);
our $VERSION = '0.0.1';

# Raw classes can include a timestamp value which allows us to normalize
my $tsProperty = 'Timestamp_Sys100NS';

# Fetches the 'Cooked' Win32 counters.
# https://msdn.microsoft.com/en-us/library/aa394253(v=vs.85).aspx
sub getWin32Props {
    my $win32Namespace = shift;
    my $win32Class     = shift;
    my @win32Props     = @_;

    my $wmi = Win32::OLE->GetObject($win32Namespace)
      or die "getObject($win32Namespace): $!\n";

    # Fetch pre-formatted data.
    my $stats = fetchWin32Stats( $wmi, $win32Class, @win32Props );
    #print Dumper $stats;
    return $stats;
}

# Fetches 'Raw' Win32 counters, and manually normalizes.
# https://msdn.microsoft.com/en-us/library/aa394299(v=vs.85).aspx
sub getRawWin32Props {
    my $win32Namespace = shift;
    my $win32Class     = shift;
    my @win32Props     = @_;

    my $wmi = Win32::OLE->GetObject($win32Namespace)
      or die "getObject($win32Namespace): $!\n";

    # Fetch two data points with an idle second between.
    my $stats1 = fetchWin32StatsWithTimestamp( $wmi, $win32Class, @win32Props );
    sleep(1);
    my $stats2 = fetchWin32StatsWithTimestamp( $wmi, $win32Class, @win32Props );

    # Normalize the observed data.
    my $stats = getNormalizedDeltas( $stats1, $stats2, @win32Props );
    #print Dumper $stats;
    return $stats;
}

# Fetch specified Win32 properties including a Timestamp.
sub fetchWin32StatsWithTimestamp {
    # include Timestamp_Sys100NS for normalization
    return fetchWin32Stats( @_, $tsProperty );
}

# Fetch specified Win32 properties.
sub fetchWin32Stats {
    my $wmi        = shift;
    my $win32Class = shift;
    my @win32Props = @_;
    my %stats;

    my $instances = $wmi->InstancesOf($win32Class)
      or die "InstancesOf($win32Class): $!\n";

    # Iterate over the matching instances of the specified class.
    foreach my $v ( $instances->in() ) {
        # Avoid stale values.
        $v->Refresh_();
        if ( defined $v->{Name} ) {
            map { $stats{ $v->{Name} }->{$_} = $v->{$_} } @win32Props;
        } else {
            map { $stats{$_} = $v->{$_} } @win32Props;
        }
    }

    #print Dumper \%stats;
    return \%stats;
}

# Given two snapshots of usage with a TimeStamp_Sys100NS key, produce metrics
# per second.
sub getNormalizedDeltas {
    my $h1         = shift;
    my $h2         = shift;
    my @win32Props = @_;
    my %stats;

    foreach my $name ( keys %$h1 ) {
        # Get the time delta.
        my $time = $h2->{$name}->{$tsProperty} - $h1->{$name}->{$tsProperty};
        # For each delta, divide by the time delta.
        foreach my $key (@win32Props) {
            my $delta = $h2->{$name}->{$key} - $h1->{$name}->{$key};
            $delta /= $time;
            # Normalize percent fields to whole numbers.
            $delta *= 100 if ( $key =~ /^Percent/ );
            $stats{$name}->{$key} = $delta;
        }
    }

    return \%stats;
}

1;
