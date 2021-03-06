package MotoViz::TangoLoggerProcessor;
use strict;
use warnings;
use base 'MotoViz::InputFileProcessor';    # sets @MotoViz::TangoLoggerProcessor::ISA = ('MotoViz::InputFileProcessor');
use Dancer ':syntax';
use Time::Local;
use Data::Dump qw( pp );

my $headers = {
    v1 => [ 'current_millis','diff_millis','count','iterations','date','time','speed_gps','speed_rpm','lat','lon','heading','distance_gps','distance_rpm','batt_voltage','batt_current_reading','batt_current','motor_current','motor_voltage','motor_watts','wh/m_gps','wh/m_rpm','m/kwh_gps','m/kwh_rpm','motor_temp_calc','motor_thermistor_reading','brake_a/d','tps_a/d','controller_power','5v_power','b+','ia','ib','ic','va','vb','vc','pwm','enable_motor_rotation','motor_temp','controller_temp','high_mosfet','low_mosfet','rpm_high','rpm_low','current_%','error_high','error_low'],
    v2 => [ 'current_millis','diff_millis','count','iterations','date','time','fix_age','speed_gps','speed_rpm','lat','lon','altitude','heading','distance_gps','distance_rpm','batt_voltage','batt_current_reading','batt_current','motor_current','motor_voltage','motor_watts','wh/m_gps','wh/m_rpm','m/kwh_gps','m/kwh_rpm','motor_temp_calc','motor_thermistor_reading','brake_a/d','tps_a/d','controller_power','5v_power','b+','ia','ib','ic','va','vb','vc','pwm','enable_motor_rotation','motor_temp','controller_temp','high_mosfet','low_mosfet','rpm_high','rpm_low','current_%','error_high','error_low'],
    v3 => [ 'current_millis','diff_millis','count','iterations','date','time','fix_age','speed_gps','speed_rpm','lat','lon','altitude','heading','failed_cs','distance_gps','distance_rpm','batt_voltage','batt_current_reading','batt_current','motor_current','motor_voltage','motor_watts','wh/m_gps','wh/m_rpm','m/kwh_gps','m/kwh_rpm','motor_temp_calc','motor_thermistor_reading','brake_a/d','tps_a/d','controller_power','5v_power','b+','ia','ib','ic','va','vb','vc','pwm','enable_motor_rotation','motor_temp','controller_temp','high_mosfet','low_mosfet','rpm_high','rpm_low','current_%','error_high','error_low'],
    v4 => [ 'current_millis','diff_millis','count','iterations','date','time','fix_age','speed_gps','speed_rpm','lat','lon','altitude','heading','failed_cs','distance_gps','distance_rpm','batt_voltage','batt_current_reading_total','batt_current_Avg','batt_current_reading_single', 'batt_current_single', 'motor_current','motor_voltage','motor_watts','wh/m_gps','wh/m_rpm','wh/m_trip','m/kwh_gps','m/kwh_rpm','m/kwh_trip','motor_temp_calc','motor_thermistor_reading','brake_a/d','tps_a/d','controller_power','5v_power','b+','ia','ib','ic','va','vb','vc','pwm','enable_motor_rotation','motor_temp','controller_temp','high_mosfet','low_mosfet','rpm_high','rpm_low','current_%','error_high','error_low'],
    v5 => [ 'current_millis','diff_millis','count','iterations','date','time','fix_age','speed_gps','speed_rpm','lat','lon','altitude','heading','failed_cs','distance_gps','distance_rpm','batt_voltage','batt_current_reading_total','batt_current_Avg','batt_current_reading_single', 'batt_current_single', 'wh', 'wh_total', 'motor_current','motor_voltage','motor_watts','wh/m_gps','wh/m_rpm','wh/m_trip','m/kwh_gps','m/kwh_rpm','m/kwh_trip','motor_temp_calc','motor_thermistor_reading','brake_a/d','tps_a/d','controller_power','5v_power','b+','ia','ib','ic','va','vb','vc','pwm','enable_motor_rotation','motor_temp','controller_temp','high_mosfet','low_mosfet','rpm_high','rpm_low','current_%','error_high','error_low'],
    v6 => [ 'current_millis','diff_millis','iterations','date','time','fix_age','speed_gps','speed_rpm','speed_controller', 'lat','lon','heading','altitude','failed_cs','distance_gps','distance_rpm','rpm_controller', 'batt_voltage','batt_current_reading_total','batt_current_Avg','batt_current_reading_single', 'batt_current_single', 'batt_current_controller', 'wh', 'wh_total', 'motor_current','motor_voltage','motor_watts','wh/m_gps','wh/m_rpm','wh/m_trip','m/kwh_gps','m/kwh_rpm','m/kwh_trip','motor_temp', 'motor_temp_calc','motor_thermistor_reading','throttle_percent', 'bdi', 'controller_heatsink_temp' ],
    #v6 => [ 'current_millis','current_corrected_millis','diff_millis','iterations','date','time','fix_age','speed_gps','speed_rpm','speed_controller', 'lat','lon','heading','altitude','failed_cs','distance_gps','distance_rpm','rpm_controller', 'batt_voltage','batt_current_reading_total','batt_current_Avg','batt_current_reading_single', 'batt_current_single', 'batt_current_controller', 'wh', 'wh_total', 'motor_current','motor_voltage','motor_watts','wh/m_gps','wh/m_rpm','wh/m_trip','m/kwh_gps','m/kwh_rpm','m/kwh_trip','motor_temp', 'motor_temp_calc','motor_thermistor_reading','throttle_percent', 'bdi', 'controller_heatsink_temp' ],
    v7 => [ 'current_millis','current_corrected_millis','diff_millis','loops_since_last_log','date','time','fix_age','speed_gps','speed_rpm','speed_controller', 'lat','lon','heading','altitude','failed_cs','distance_gps','distance_rpm','rpm_controller', 'batt_voltage','batt_current_reading_total','batt_current_Avg','batt_current_reading_single', 'batt_current_single', 'batt_current_controller', 'wh', 'wh_total', 'motor_current','motor_voltage','motor_watts','wh/m_gps','wh/m_rpm','wh/m_trip','m/kwh_gps','m/kwh_rpm','m/kwh_trip','motor_temp', 'motor_temp_calc','motor_thermistor_reading','throttle_percent', 'bdi', 'controller_heatsink_temp' ],
    v8 => [ 'current_millis','current_corrected_millis','diff_millis','loops_since_last_log','date','time','fix_age','speed_gps','speed_rpm','speed_controller', 'lat','lon','heading','altitude','failed_cs','distance_gps','distance_rpm','rpm_controller', 'batt_voltage','batt_current_reading_total','batt_current_Avg','batt_current_reading_single', 'batt_current_single', 'batt_current_controller', 'wh', 'wh_total', 'motor_current','motor_voltage','motor_watts','wh/m_gps','wh/m_rpm','wh/m_trip','m/kwh_gps','m/kwh_rpm','m/kwh_trip','motor_temp', 'motor_temp_calc','motor_thermistor_reading','throttle_percent', 'bdi', 'controller_heatsink_temp', 'reverse_switch', '3A_packet_age', '3B_packet_age' ],
};


sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    return $self;
}

sub init {
    my $self = shift;
    my $ride_id = shift;
    $self->{'tango_file'} = shift;
    $self->{'id'} = 'TangoLogger_V1';
    $self->{'rev'} = 1;

    $self->{'header'} = $headers->{'v1'};
    my $ret = $self->verifyTangoFile ( $self->{'tango_file'} );
    if ( $ret->{'code'} <= 0 ) {
        log_error ( pp ( $ret ) );
    }
    if ( $ret->{'data'} == 0 ) {
        return { code => 0, message => 'Tango log file is invalid. (' . $self->{'tango_file'} . ')'  . ', ' . pp ( $ret )  };
    }

    if ( ! open ( $self->{'tango_fh'}, $self->{'tango_file'} ) ) {
        return { code => -1, message => 'failed to open tago log file: ' . $self->{'tango_file'} . '. Error: ' . $! };
    }

    $self->{'ride_id'} = $ride_id;

#     $self->{'last_distance_sensor_total'} = 0;
#     $self->{'last_record'} = undef;
#     $self->{'point_num'} = 0;
#     $self->{'speed_total'} = 0;
#     $self->{'time_last'} = 0;
#     $self->{'ca_line_count'} = 0;
#     $self->{'distance_gps_total'} = 0;
    return { code => 1, message => 'ok' };
}

sub getInputInfo {
    my $self = shift;
    return { tango_file => $self->{'tango_file'} };
}

sub getInputType {
    my $self = shift;
    return $self->{'id'};
}

sub getNextRecord {
    my $self = shift;

    my $tango_file = $self->{'tango_file'};
    my $record = {
        ride_id => $self->{'ride_id'},
    };
    
    my $fh = $self->{'tango_fh'};
    my $tango_line;
    while ( $tango_line = <$fh> ) {
        if ( $tango_line =~ /LOGFMT (\d+)/ ) {
            my $rev = $1;
            $self->{'rev'} = $rev;
            $self->{'id'} = 'TangoLogger_V' . $rev;
            $self->{'header'} = $headers->{'v' . $rev};
            next;
        }
        my $hash = {};
        my @arr = split ( /,/, $tango_line );
        for ( my $i = 0; $i < @{$self->{'header'}}; $i++ ) {
            $hash->{$self->{'header'}->[$i]} = $arr[$i];
        }
        if ( ( $hash->{'date'} > 0 ) && ( $hash->{'time'} > 0 ) ) {
            my ( $year, $mon, $day ) = $hash->{'date'} =~ /(\d\d\d\d)(\d\d)(\d\d)/;
            my ( $hour, $min, $sec ) = $hash->{'time'} =~ /(\d\d)(\d\d)(\d\d)/;
            next if ( $hash->{'date'} == 20000000 );
            $mon--;
            $record->{'time'} = timegm ( $sec, $min, $hour, $day, $mon, $year ) . '.000';
            next if ( $year < 2005 );
        } else {
            next;
        }
        $record->{'battery_amps'} = ( $self->{'rev'} >= 4 ) ? $hash->{'batt_current_Avg'} : $hash->{'batt_current'};
        $record->{'battery_volts'} = $hash->{'batt_voltage'};
        $record->{'rpm_controller'} = $hash->{'rpm_controller'};
        $record->{'speed_sensor'} = $hash->{'speed_rpm'};
        $record->{'speed_gps'} = $hash->{'speed_gps'};
        $record->{'watts'} = $record->{'battery_amps'} * $record->{'battery_volts'};
        $record->{'distance_sensor_delta'} = $record->{'distance_rpm'};
        $record->{'lat'} = $hash->{'lat'};
        $record->{'lon'} = $hash->{'lon'};
        $record->{'altitude'} = $hash->{'altitude'} || 0;
        $record->{'motor_temp_controller'} = $hash->{'motor_temp'} || 0;
        $record->{'motor_temp_sensor'} = $hash->{'motor_temp_calc'} || 0;
        $record->{'throttle_percent'} = ( $self->{'rev'} >= 6 ) ? $hash->{'throttle_percent'} : ( $hash->{'tps_a/d'} / 255 * 100 ) || 0;
        #$record->{'distance_sensor_total'} = 
        #$record->{'battery_amp_hours'} = 
        if ( $self->{'last_record'} ) {
            $record->{'distance_gps_delta'} = $hash->{'distance_gps'};
            $record->{'time_diff'} = $hash->{'diff_millis'};
            $record->{'battery_watt_hours'} = $record->{'battery_amps'} * $record->{'battery_volts'} * $record->{'time_diff'} / 3600000;
            $self->{'distance_gps_total'} += $record->{'distance_gps_delta'};
            $record->{'distance_gps_total'} = $self->{'distance_gps_total'};

            if ( $record->{'time_diff'} < 5000 ) {
                $record->{'wh'} = $record->{'watts'} * $record->{'time_diff'} / 3600000;
                if ( $record->{'distance_gps_delta'} > 0.0000001 ) {
                    $record->{'whPerMile'} = ( $record->{'distance_gps_delta'} ) ? $record->{'wh'} / $record->{'distance_gps_delta'} : 0;
                    $record->{'milesPerKWh'} = ( $record->{'wh'} ) ? $record->{'distance_gps_delta'} / $record->{'wh'} * 1000 : 0;
                    if ( ( $record->{'whPerMile'} > 400 ) || ( $record->{'milesPerKWh'} > 400 ) ) {
                        $record->{'whPerMile'} = 0;
                        $record->{'milesPerKWh'} = 0;
                    }
                }
            }
            #$self->{'time_last'} = $tDiff;
        }
        $self->{'last_record'} = $record;
        #print pp ( $hash ) . "\n";
        #print pp ( $record ) . "\n";
        return { code => 1, data => $record };
    }
        
#             $record->{'ca_line_count'} = $self->{'ca_line_count'};
#         }
#     }
# 
#     if ( ! $ca_log_line ) {
        return { code => 0, message => 'no more records' };
#     }
}

    #
    # Ensure that the tango_log_file is actually a CycleAnalyst log file.
    #
sub verifyTangoFile {
    my $self = shift;
    my $tango_file = shift;
    my $fh;
    if ( ! $tango_file ) {
        return { code => 1, data => 0, message => 'Tango log file not defined' };
    }
    open ( $fh, $tango_file ) || do {
        return { code => 1, data => 0, message => 'Failed opening Tango log file "' . $tango_file . '". Error: ' . $! };
    };

    my $count = 0;
    my $successes = 0;
    while ( $count <= 6 ) {
        my $line = <$fh>;
        if ( $line =~ /LOGFMT (\d+)/ ) {
            my $v = $1;
            debug ( "version: v$1" );
            $self->{'header'} = $headers->{'v' . $v};
            next;
        }
        if ( $line ) {
            chomp ( $line );
            chomp ( $line );
            $line =~ s/,\s*$//;
            debug ( $line );
            my @arr = split ( /,/, $line );
            debug ( "scalar \@arr: " . scalar @arr );
            debug ( "scalar \@{self->{'header'}}: " . scalar @{$self->{'header'}} );
            if ( scalar @arr == ( scalar @{$self->{'header'}} ) ) {
                $successes++;
            }
        }
        $count++;
    }
    #debug ( "Done.  Sueccesses: $successes, count: $count" );
    close ( $fh );
    if ( $successes >= 4 ) {
        return { code => 1, data => 1 };
    } else {
        return { code => 1, data => 0, message => 'not enough successful lines parsed'  };
    }
}

1;
