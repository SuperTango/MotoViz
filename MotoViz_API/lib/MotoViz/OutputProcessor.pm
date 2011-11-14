package MotoViz::OutputProcessor;
use strict;
use warnings;
use Dancer ':syntax';
use GPS::Point;
use Time::Local;
use Data::Dump qw( pp );
use Algorithm::GooglePolylineEncoding;

use MotoViz::NMEAParser;

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    return $self;
}

sub init {
    my $self = shift;
    my $user_id = shift;
    my $ride_id = shift;
    my $title = shift;
    my $visibility = shift;
    my $input_processor = shift;

    $self->{'user_id'} = $user_id;
    $self->{'ride_id'} = $ride_id;
    $self->{'title'} = $title;
    $self->{'visibility'} = ( $visibility ) || 'private';
    $self->{'input_processor'} = $input_processor;

    return { code => 1, message => 'success' };
}

sub generateOutputFiles {
    my $self = shift;
    my $output_dir = shift;

    my $user_id = $self->{'user_id'};
    my $ride_id = $self->{'ride_id'};

    if ( ! $output_dir ) {
        $output_dir = setting ( 'raw_log_dir' ) . '/' . $user_id . '/' . $ride_id;
    }


    my $ride_info = {
        'lat_min' => 1000,
        'lat_max' => -1000,
        'lon_min' => 1000,
        'lon_max' => -1000,
        ride_id => $self->{'ride_id'},
        user_id => $self->{'user_id'},
        points_count => 0,
        speed_max => 0,
        input_data_type => $self->{'input_processor'}->getInputType(),
        input_data_source => $self->{'input_processor'}->getInputInfo(),
        title => $self->{'title'},
        visibility => $self->{'visibility'},
        wh_total => 0,
    };

    my $speed_total;
    my $ret;
    my $new_data = { 
        altitude => [],
        battery_amps => [],
        battery_volts => [],
        battery_watt_hours => [],
        distance_gps_delta => [],
        distance_gps_total => [],
        distance_sensor_delta => [],
        lat => [],
        lon => [],
        motor_temp_controller => [],
        motor_temp_sensor => [],
        milesPerKWh => [],
        speed_gps => [],
        speed_sensor => [],
        throttle_percent => [],
        time => [],
        time_diff => [],
        watts => [],
        wh => [],
        whPerMile => [],
    };

    my $latLonArray = [];

    while ( $ret = $self->{'input_processor'}->getNextRecord() ) {
        if ( $ret->{'code'} == 0 ) {
                
            $ride_info->{'speed_avg'} = $speed_total / $ride_info->{'points_count'};
            $ride_info->{'wh_per_mile'} = $ride_info->{'wh_total'} / $ride_info->{'distance_gps_total'};
            $ride_info->{'miles_per_kwh'} = $ride_info->{'distance_gps_total'} / ( $ride_info->{'wh_total'} / 1000 );
            $ride_info->{'input_data_type'} = $self->{'input_processor'}->getInputType();

            my $limitPoints = 100;
            my $mod = int ( scalar ( @{$latLonArray} ) / $limitPoints );
            my $lastInt = -1;
            my @latLonTrimmed;
            for ( my $i = 0; $i < scalar ( @{$latLonArray} ); $i++ ) {
                my $tmp = int ( $i / $mod );
                if ( $tmp != $lastInt ) {
                    push ( @latLonTrimmed, $latLonArray->[$i] );
                    $lastInt = $tmp;
                }
            }
            $ride_info->{'map_polyline'} = Algorithm::GooglePolylineEncoding::encode_polyline(@latLonTrimmed);

                # write files to disk
            my $combined_data_file = $output_dir . '/combined.json';
            my $combined_data_fh;
            if ( ! open ( $combined_data_fh, '>', $combined_data_file ) ) {
                return { code => -1, message => 'failed to open new_data log file for writing: ' . $combined_data_file . '. Error: ' . $! };
            }
            print $combined_data_fh to_json ( $new_data );
            close ( $combined_data_fh );

debug ( pp ( $ride_info ) );
            foreach my $metric ( @{$ride_info->{'metrics'}} ) {
                my $metric_file = $output_dir . '/metric-' . $metric . '.json';
                my $metric_fh;
                if ( ! open ( $metric_fh, '>', $metric_file ) ) {
                    return { code => -1, message => 'failed to open metrics log file for writing: ' . $metric_file . '. Error: ' . $! };
                }
                debug ( "dumping metric: " . $metric );
                print $metric_fh to_json ( $new_data->{$metric} );
                close ( $metric_fh );
            }

            my $output_meta_file = $output_dir . '/ride_info.json';
            my $output_meta_fh;
            if ( ! open ( $output_meta_fh, '>', $output_meta_file ) ) {
                return { code => -1, message => 'failed to open output_meta log file for writing: ' . $output_meta_file . '. Error: ' . $! };
            }
            print $output_meta_fh to_json ( $ride_info, { pretty => 1, canonical => 1 } );
            return { code => 1, message => 'done!' };
        }
        my $record = $ret->{'data'};
        next if ( ! $record->{'lat'} );
        if ( ! $ride_info->{'metrics'} ) {
            #@{$ride_info->{'metrics'}} = grep ( !/ride_id/, ( sort ( keys ( %{$record} ) ) ) );
            @{$ride_info->{'metrics'}} = keys ( %{$new_data} );
        }
        foreach my $key ( keys ( %{$new_data} ) ) {
            my $value = $record->{$key} || 0;
            push ( @{$new_data->{$key}}, $value + 0 );
        }

        if ( exists ( $record->{'lat'} ) ) {
            $ride_info->{'lat_min'} = $record->{'lat'} if ( $record->{'lat'} < $ride_info->{'lat_min'} );
            $ride_info->{'lat_max'} = $record->{'lat'} if ( $record->{'lat'} > $ride_info->{'lat_max'} );
            $ride_info->{'lon_min'} = $record->{'lon'} if ( $record->{'lon'} < $ride_info->{'lon_min'} );
            $ride_info->{'lon_max'} = $record->{'lon'} if ( $record->{'lon'} > $ride_info->{'lon_max'} );
            if ( ! $ride_info->{'lat_start'} ) {
                $ride_info->{'lat_start'} = $record->{'lat'};
                $ride_info->{'lon_start'} = $record->{'lon'};
                $ride_info->{'time_start'} = $record->{'time'};
            }
            $ride_info->{'lat_end'} = $record->{'lat'};
            $ride_info->{'lon_end'} = $record->{'lon'};
            $ride_info->{'time_end'} = $record->{'time'};
            $ride_info->{'distance_sensor_total'} = $record->{'distance_sensor_total'};

            if ( $record->{'speed_gps'} ) {
                if ( $record->{'speed_gps'} > $ride_info->{'speed_max'} ) {
                    $ride_info->{'speed_max'} = $record->{'speed_gps'};
                }
                $speed_total += $record->{'speed_gps'};
            }
            push ( @{$latLonArray}, { lat => $record->{'lat'}, lon => $record->{'lon'} } );
        }
        $ride_info->{'wh_total'} += ( $record->{'battery_watt_hours'} ) ? $record->{'battery_watt_hours'} : 0;
        $ride_info->{'points_count'}++;
        $ride_info->{'distance_gps_total'} = $record->{'distance_gps_total'};
    }
    return { code => -1, message => 'should never get here!' };
}
1;
