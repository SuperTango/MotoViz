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
    my $public = shift;
    my $input_processor = shift;

    $self->{'user_id'} = $user_id;
    $self->{'ride_id'} = $ride_id;
    $self->{'title'} = $title;
    $self->{'public'} = $public;
    $self->{'input_processor'} = $input_processor;

    return { code => 1, message => 'success' };
}

sub generateOutputFile {
    my $self = shift;
    my $output_file = shift;

    my $user_id = $self->{'user_id'};
    my $ride_id = $self->{'ride_id'};

    if ( ! $output_file ) {
        $output_file = setting ( 'raw_log_dir' ) . '/' . $user_id . '/' . $ride_id . '/motoviz_output.out';
    }

    my $output_meta_file = $output_file . '.meta';

    my $output_fh;
    if ( ! open ( $output_fh, '>', $output_file ) ) {
        return { code => -1, message => 'failed to open output log file for writing: ' . $output_file . '. Error: ' . $! };
    }

    my $output_meta_fh;
    if ( ! open ( $output_meta_fh, '>', $output_meta_file ) ) {
        return { code => -1, message => 'failed to open output_meta log file for writing: ' . $output_meta_file . '. Error: ' . $! };
    }

    my $new_data_fh;
    my $new_data_file = $output_file . '.client.json';
    if ( ! open ( $new_data_fh, '>', $new_data_file ) ) {
        return { code => -1, message => 'failed to open new_data log file for writing: ' . $new_data_file . '. Error: ' . $! };
    }

    my $ride_data = {
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
        public => $self->{'public'},
        output_file => $output_file,
        wh_total => 0,
    };

    my $speed_total;
    my $ret;
    my $new_data = { 
        battery_amps => [],
        battery_volts => [],
        battery_watt_hours => [],
        distance_gps_delta => [],
        distance_gps_total => [],
        distance_sensor_delta => [],
        lat => [],
        lon => [],
        milesPerKWh => [],
        speed_gps => [],
        speed_sensor => [],
        time => [],
        time_diff => [],
        watts => [],
        wh => [],
        whPerMile => [],
    };

    my $latLonArray = [];

    while ( $ret = $self->{'input_processor'}->getNextRecord() ) {
        if ( $ret->{'code'} == 0 ) {
                
                #
                # needed for DB datastore.
                # make sure you 'use Dancer::Plugin::DBIC';
                #
            #my $row = schema->resultset('Ride')->find( $ride_data->{'ride_id'} );
            #if ( $row ) {
            #    $row->delete;
            #}
            #my $new_ride = schema->resultset('Ride')->create( $ride_data );

            print $new_data_fh to_json ( $new_data );
            close ( $new_data_fh );

            $ride_data->{'speed_avg'} = $speed_total / $ride_data->{'points_count'};
            $ride_data->{'wh_per_mile'} = $ride_data->{'wh_total'} / $ride_data->{'distance_gps_total'};
            $ride_data->{'miles_per_kwh'} = $ride_data->{'distance_gps_total'} / ( $ride_data->{'wh_total'} / 1000 );
            debug ( pp ( $latLonArray ) );

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
            $ride_data->{'map_polyline'} = Algorithm::GooglePolylineEncoding::encode_polyline(@latLonTrimmed);

            debug ( 'ride_data: ' . pp ( $ride_data ) );

                #
                # needed for file datastore
                #
            print $output_meta_fh to_json ( $ride_data, { pretty => 1, canonical => 1 } );
            return { code => 1, message => 'done!' };
        }
        my $record = $ret->{'data'};
        next if ( ! $record->{'lat'} );
        foreach my $key ( keys ( %{$new_data} ) ) {
            my $value = $record->{$key} || 0;
            push ( @{$new_data->{$key}}, $value + 0 );
        }

        if ( exists ( $record->{'lat'} ) ) {
            $ride_data->{'lat_min'} = $record->{'lat'} if ( $record->{'lat'} < $ride_data->{'lat_min'} );
            $ride_data->{'lat_max'} = $record->{'lat'} if ( $record->{'lat'} > $ride_data->{'lat_max'} );
            $ride_data->{'lon_min'} = $record->{'lon'} if ( $record->{'lon'} < $ride_data->{'lon_min'} );
            $ride_data->{'lon_max'} = $record->{'lon'} if ( $record->{'lon'} > $ride_data->{'lon_max'} );
            if ( ! $ride_data->{'lat_start'} ) {
                $ride_data->{'lat_start'} = $record->{'lat'};
                $ride_data->{'lon_start'} = $record->{'lon'};
                $ride_data->{'time_start'} = $record->{'time'};
            }
            $ride_data->{'lat_end'} = $record->{'lat'};
            $ride_data->{'lon_end'} = $record->{'lon'};
            $ride_data->{'time_end'} = $record->{'time'};
            $ride_data->{'distance_sensor_total'} = $record->{'distance_sensor_total'};

            if ( $record->{'speed_gps'} ) {
                if ( $record->{'speed_gps'} > $ride_data->{'speed_max'} ) {
                    $ride_data->{'speed_max'} = $record->{'speed_gps'};
                }
                $speed_total += $record->{'speed_gps'};
            }
            push ( @{$latLonArray}, { lat => $record->{'lat'}, lon => $record->{'lon'} } );
        }
        $ride_data->{'wh_total'} += ( $record->{'battery_watt_hours'} ) ? $record->{'battery_watt_hours'} : 0;
        $ride_data->{'points_count'}++;
        $ride_data->{'distance_gps_total'} = $record->{'distance_gps_total'};

        print $output_fh to_json ( $record, { pretty => 0, canonical => 1 } ). "\n";
    }
    return { code => -1, message => 'should never get here!' };
}
1;
