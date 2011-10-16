package MotoViz::CAFileProcessor;
use strict;
use warnings;
use base 'MotoViz::InputFileProcessor';    # sets @MotoViz::CAFileProcessor::ISA = ('MotoViz::InputFileProcessor');
use Dancer ':syntax';
use GPS::Point;
use Time::Local;
use Data::Dump qw( pp );

use MotoViz::NMEAParser;

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    return $self;
}

sub init {
    my $self = shift;
    my $ride_id = shift;
    $self->{'ca_log_file'} = shift;
    $self->{'ca_gps_file'} = shift;

    my $ret = $self->verifyCALogFile ( $self->{'ca_log_file'} );
    if ( $ret->{'code'} <= 0 ) {
        log_error ( pp ( $ret ) );
    }
    if ( $ret->{'data'} == 0 ) {
        return { code => 0, message => 'CA log file is invalid.' };
    }

    if ( ! open ( $self->{'ca_log_fh'}, $self->{'ca_log_file'} ) ) {
        return { code => -1, message => 'failed to open ca log file: ' . $self->{'ca_log_file'} . '. Error: ' . $! };
    }

    my $nmea_parser = new MotoViz::NMEAParser;
    $ret = $nmea_parser->init ( $self->{'ca_gps_file'} );
    $self->{'nmea_parser'} = $nmea_parser;
    $self->{'ride_id'} = $ride_id;

    $self->{'last_distance_sensor_total'} = 0;
    $self->{'last_record'} = undef;
    $self->{'point_num'} = 0;
    $self->{'speed_total'} = 0;
    $self->{'time_last'} = 0;
    $self->{'ca_line_count'} = 0;
    $self->{'distance_gps_total'} = 0;
    return { code => 1, message => 'ok' };
}

sub getInputInfo {
    my $self = shift;
    return { ca_log_file => $self->{'ca_log_file'}, ca_gps_file => $self->{'ca_gps_file'} };
}

sub getInputType {
    my $self = shift;
    return "CycleAnalyst";
}

sub getNextRecord {
    my $self = shift;

    my $ca_log_file = $self->{'ca_log_file'};
    my $nmea_parser = $self->{'nmea_parser'};
    my $record = {
        ride_id => $self->{'ride_id'},
    };

    my $fh = $self->{'ca_log_fh'};
    my $ca_log_line;
    while ( $ca_log_line = <$fh> ) {
        my @arr = split ( /\s+/, $ca_log_line );
        next if ( @arr < 5 );
        next if ( $arr[0] !~ /\d+/ );
        $self->{'point_num'}++;
        $record->{'point_num'} = $self->{'point_num'};
        chomp ( $ca_log_line );
        $self->{'ca_line_count'}++;
        if ( ( $self->{'ca_line_count'} % 5 ) == 1 ) {
            (   $record->{'battery_amp_hours'}, 
                $record->{'battery_volts'}, 
                $record->{'battery_amps'}, 
                $record->{'speed_sensor'}, 
                $record->{'distance_sensor_total'} ) = @arr;
            $record->{'watts'} = $record->{'battery_amps'} * $record->{'battery_volts'};
            $record->{'distance_sensor_delta'} = $record->{'distance_sensor_total'} - $self->{'last_distance_sensor_total'};
            $self->{'last_distance_sensor_total'} = $record->{'distance_sensor_total'};
            $record->{'ca_log_line'} = $ca_log_line;
            $nmea_parser->get_next_record ( $record );
            
            if ( exists ( $record->{'lat'} ) ) {
                my $gps_point = GPS::Point->newMulti ( $record->{'lat'}, $record->{'lon'}, 0 );
                if ( $self->{'last_gps_point'} ) {
                    $record->{'distance_gps_delta'} = 0.000621371192 * $gps_point->distance ( $self->{'last_gps_point'} );
                    $record->{'time_diff'} = $record->{'time'} -  $self->{'last_record'}->{'time'};
                    $record->{'battery_watt_hours'} = $record->{'battery_volts'} * $record->{'battery_volts'} * $record->{'time_diff'} / 3600;
                    $self->{'distance_gps_total'} += $record->{'distance_gps_delta'};
                    $record->{'distance_gps_total'} = $self->{'distance_gps_total'};

                    my $tDiff = $record->{'time'} - $self->{'time_last'};
                    if ( $tDiff < 5000 ) {
                        $record->{'wh'} = $record->{'watts'} * $tDiff / 3600000;
                        if ( $record->{'distance_gps_delta'} > 0.0000001 ) {
                            $record->{'whPerMile'} = ( $record->{'distance_gps_delta'} ) ? $record->{'wh'} / $record->{'distance_gps_delta'} : 0;
                            $record->{'milesPerKWh'} = ( $record->{'distance_gps_delta'} ) ? $record->{'distance_gps_delta'} / $record->{'wh'} * 1000 : 0;
                            if ( ( $record->{'whPerMile'} > 400 ) || ( $record->{'milesPerKWh'} > 400 ) ) {
                                $record->{'whPerMile'} = 0;
                                $record->{'milesPerKWh'} = 0;
                            }
                        }
                    }
                    $self->{'time_last'} = $tDiff;
                }
                $self->{'last_record'} = $record;
                $self->{'last_gps_point'} = $gps_point;
            }
            $record->{'ca_line_count'} = $self->{'ca_line_count'};
            return { code => 1, data => $record };
        }
    }

    if ( ! $ca_log_line ) {
        return { code => 0, message => 'no more records' };
    }
}

    #
    # Ensure that the ca_log_file is actually a CycleAnalyst log file.
    #
sub verifyCALogFile {
    my $self = shift;
    my $ca_log_file = shift;
    my $fh;
    if ( ! $ca_log_file ) {
        return { code => 1, data => 0, message => 'CA log file not defined' };
    }
    open ( $fh, $ca_log_file ) || do {
        return { code => 1, data => 0, message => 'Failed opening CA log file "' . $ca_log_file . '". Error: ' . $! };
    };

    my $count = 0;
    my $successes = 0;
    while ( $count <= 6 ) {
        my $line = <$fh>;
        if ( $line ) {
            my @arr = split ( /\s+/, $line );
            if ( @arr == 5 ) {
                if ( ( $arr[0] eq 'Ah' ) && ( $arr[1] eq 'V' ) &&  ( $arr[2] eq 'A' ) && ( $arr[3] eq 'S' ) && ( $arr[4] eq 'D' ) ) {
                    $successes++;
                } elsif ( ( $arr[0] =~ /^\-?[\d\.\-]/ ) && ( $arr[1] =~ /^\-?[\d\.\-]/ ) && ( $arr[2] =~ /^\-?[\d\.\-]/ ) && ( $arr[3] =~ /^\-?[\d\.\-]/ ) && ( $arr[4] =~ /^\-?[\d\.\-]/ ) ) {
                    $successes++;
                }
            }
        }
        $count++;
    }
    close ( $fh );
    if ( $successes >= 4 ) {
        return { code => 1, data => 1 };
    } else {
        return { code => 1, data => 0 };
    }
}

sub verifyNMEAFile {
    my $self = shift;
    my $ca_gps_file = shift;
    my $fh;
    if ( ! $ca_gps_file ) {
        return { code => 1, data => 0, message => 'NMEA file not defined' };
    }
    open ( $fh, $ca_gps_file ) || do {
        return { code => 1, data => 0, message => 'Failed opening NMEA file "' . $ca_gps_file . '". Error: ' . $! };
    };
    my $count = 0;
    my $successes = 0;
    while ( $count <= 6  ) {
        my $line = <$fh>;
        if ( $line ) {
            if ( $line =~ /^\$(?:PSRFTXT|GP)/ ) {
                $successes++;
            }
        }
        $count++;
    }
    if ( $successes >= 4 ) {
        return { code => 1, data => 1 };
    } else {
        return { code => 1, data => 0 };
    }
}



1;
