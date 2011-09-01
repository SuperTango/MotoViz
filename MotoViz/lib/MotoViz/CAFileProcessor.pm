package MotoViz::CAFileProcessor;
use strict;
use warnings;
use Dancer ':syntax';
use Dancer::Plugin::DBIC;
use GPS::Point;
use Time::Local;
use Data::Dump qw( pp );

use MotoViz::NMEAParser;

sub new {
    my $class = shift;
    my $self = {};
    $self->{'ready'} = 0;
    bless $self, $class;
    return $self;
}


sub processCAFiles {
    my $self = shift;
    my $user_id = shift;
    my $ride_id = shift;
    my $ca_log_file = shift;
    my $ca_gps_file = shift;

    my $ca_log_fh;
    if ( ! open ( $ca_log_fh, $ca_log_file ) ) {
        return { code => -1, message => 'failed to open ca log file: ' . $ca_log_file . '. Error: ' . $! };
    }

    my $json = JSON->new->allow_nonref;
    my $nmeaParser = new MotoViz::NMEAParser;
    my $ret = $nmeaParser->init ( $ca_gps_file );

    my $ca_line_count = 0;
    my $ride_data = {
        'lat_min' => 1000,
        'lat_max' => -1000,
        'lon_min' => 1000,
        'lon_max' => -1000,
        ride_id => $ride_id,
        user_id => $user_id,
        record_count => 0,
    };
    my $last_gps_point;
    my $last_distance_sensor_total = 0;
    my $last_record;
    my $point_num = 0;

    while ( my $ca_log_line = <$ca_log_fh> ) {
        my @arr = split ( /\s+/, $ca_log_line );
        next if ( @arr < 5 );
        next if ( $arr[0] !~ /\d+/ );
        $point_num++;
        my $raw_data = {};
        chomp ( $ca_log_line );
        if ( ( $ca_line_count % 5 ) == 0 ) {
            my $record = {
                ride_id => $ride_id,
                point_num => $point_num,
            };
            (   $record->{'battery_amp_hours'}, 
                $record->{'battery_volts'}, 
                $record->{'battery_amps'}, 
                $record->{'speed_sensor'}, 
                $record->{'distance_sensor_total'} ) = @arr;
            $record->{'distance_sensor_delta'} = $record->{'distance_sensor_total'} - $last_distance_sensor_total;
            $last_distance_sensor_total = $record->{'distance_sensor_total'};
            $raw_data->{'ca_log_line'} = $ca_log_line;
            $nmeaParser->get_next_record ( $record );
            #debug ( pp ( $record ) ) ;
            if ( exists ( $record->{'lat'} ) ) {
                $ride_data->{'lat_min'} = $record->{'lat'} if ( $record->{'lat'} < $ride_data->{'lat_min'} );
                $ride_data->{'lat_max'} = $record->{'lat'} if ( $record->{'lat'} > $ride_data->{'lat_max'} );
                $ride_data->{'lon_min'} = $record->{'lon'} if ( $record->{'lon'} < $ride_data->{'lon_min'} );
                $ride_data->{'lon_max'} = $record->{'lon'} if ( $record->{'lon'} > $ride_data->{'lon_max'} );
                my $gps_point = GPS::Point->newMulti ( $record->{'lat'}, $record->{'lon'}, 0 );
                if ( $last_gps_point ) {
                    $record->{'gps_distance'} = 0.000621371192 * $gps_point->distance ( $last_gps_point );
                    $record->{'time_diff'} = $record->{'timestamp'} - $last_record->{'timestamp'};
                    $record->{'battery_watt_hours'} = $record->{'battery_volts'} * $record->{'battery_volts'} * $record->{'time_diff'} / 3600;
                    $ride_data->{'total_gps_distance'} += $record->{'gps_distance'};
                    $ride_data->{'wh_total'} += $record->{'battery_watt_hours'};
                }
                $last_record = $record;
                $last_gps_point = $gps_point;
                #print $output_fh $json->encode ( $record ) . "\n";
# TODO: write to DB here.
                $ride_data->{'record_count'}++;
                #push ( @{$ride_data->{'records'}}, $record );

            }
            $record->{'raw_data'} = $json->encode ( $raw_data );
#             if ( exists ( $record->{'datetime'} ) ) {
#                 if ( ! $ride_data->{'first_datetime'} ) {
#                     $ride_data->{'first_datetime'} = $record->{'datetime'};
#                 }
#                 $ride_data->{'last_datetime'} = $record->{'datetime'};
#             }
        }
        $ca_line_count++;
    }
    $ride_data->{'lat_mid'} = $ride_data->{'lat_min'} + ( ( $ride_data->{'lat_max'} - $ride_data->{'lat_min'} ) / 2 );
    $ride_data->{'lon_mid'} = $ride_data->{'lon_min'} + ( ( $ride_data->{'lon_max'} - $ride_data->{'lon_min'} ) / 2 );
    $ride_data->{'wh_per_mile'} = $ride_data->{'wh_total'} / $ride_data->{'total_gps_distance'};
    $ride_data->{'miles_per_kWh'} = $ride_data->{'total_gps_distance'} / ( $ride_data->{'wh_total'} / 1000 );
    debug ( 'ride_data: ' . pp ( $ride_data ) );
    #$ride_data->{'skip'} = $query->param ( 'skip' );
   # print $output_meta_fh $json->pretty->encode ( { record_count => $ride_data->{'record_count'} } ) . "\n";
    # TODO: print $output_meta_fh $json->pretty->encode ( $ride_data );
}
1;
