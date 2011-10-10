package RESTRoutes;
use Dancer ':syntax';
use Data::Dump qw( pp );
use Data::UUID;
use File::Path;
use MotoViz::CAFileProcessor;
use MotoViz::TangoLoggerProcessor;
use MotoViz::OutputProcessor;
use MotoViz::RideInfo;

our $VERSION = '0.1';

sub return_json {
    my $data = shift;
    my $options = shift;
    debug ( pp ( params ) );
    my $ret;
    if ( exists params->{'callback'} ) {
        $ret = params->{'callback'} . '(';
        content_type "text/javascript";
    } else {
        $ret = '';
        content_type "application/json";
    }
    if ( ! $options ) {
        $options = {};
    }
    $options->{'pretty'} ||= ( exists params->{'pretty'} ) ? 1 : 0;
    debug ( 'options: ' .  pp ( $options ) );

    $ret .= to_json ( $data, $options );
    $ret .= ');' if ( params->{'callback'} );
    return $ret;
}

get '/' => sub {
    return_json { message => 'MotoViz_API!' };
};

get '/v1/test' => sub {
    return_json { message => 'Good!' };
};

get '/v1/points/:user_id/:ride_id' => sub {
    my $ride_info = MotoViz::RideInfo::getRideInfo ( params->{'user_id'}, params->{'ride_id'} );
    if ( ! $ride_info ) {
        status 'not_found';
        return;
    }
    my $params = params;
    my $limit_points = params->{'limit_points'};
    my @metrics = $params->{'metrics'} || ( 'battery_volts', 'battery_amps', 'speed_gps', 'speed_sensor', 'bearing', 'lat', 'lon', 'altitude', 'watts', 'wh', 'whPerMile', 'milesPerKWh', 'distance_gps_delta'   );
    my $ret = fetch_points_average ( $ride_info, $limit_points, \@metrics );
#    my $points = fetch_points_instant ( $ride_info, $limit_points );
#     my $ret = {};
#     foreach my $point ( @{$points} ) {
#         foreach my $metric ( @metrics ) {
#             my $time = $point->{'time'} * 1000;
#             if ( ! exists $ret->{$metric} ) {
#                 $ret->{$metric} = [];
#             }
#             push ( @{$ret->{$metric}}, [ $time, ( $point->{$metric} ) ? $point->{$metric} + 0 : 0 ] );
#         }
#     }
    return return_json ( $ret );
};

del '/v1/ride/:user_id/:ride_id' => sub {
    my $ride_path = setting ( 'raw_log_dir' ) . '/' . params->{'user_id'} . '/' . params->{'ride_id'};
    if ( ! -d $ride_path ) {
        status 'not_found';
        return;
    }
    eval { 
        rmtree ( $ride_path ) 
    };
    if ( $@ ) {
        error $@;
        status 500;
    } else {
        status 204;
    }
};

get '/v1/ride/:user_id/:ride_id' => sub {
    my $ride_info = MotoViz::RideInfo::getRideInfo ( params->{'user_id'}, params->{'ride_id'} );
    if ( ! $ride_info ) {
        status 'not_found';
        return;
    }
    my $params = params;
    return return_json ( $ride_info );
};

get '/v1/ride/:user_id' => sub {
    my $ride_infos = MotoViz::RideInfo::getRideInfos ( params->{'user_id'} );
    if ( ! $ride_infos ) {
        status 'not found';
        return 'not found';
    }
    my $array = [];
    debug ( "Number of rides: " . @{$ride_infos} );
    foreach my $ride_info ( @{$ride_infos} ) {
        debug ( "cols: " . pp ( $ride_info ) );
        debug ( "got ride: " . $ride_info->{'ride_id'} );
        debug ( "userid: " . params->{'user_id'} );
        debug ( "request base: " . request->base );
        debug ( "request base: " . ref ( request->base ) );
        $ride_info->{'ride_url'} = setting ( 'api_url' ) . '/v1/ride/' . params->{'user_id'} . '/' . $ride_info->{'ride_id'};
        $ride_info->{'points_url'} = setting ( 'api_url' ) . '/v1/points/' . params->{'user_id'} . '/' . $ride_info->{'ride_id'};

        push ( @{$array}, $ride_info );
    }
    return return_json ( $array );
};

post '/v1/ride/:user_id' => sub {
    my $user_id = params->{'user_id'};
    my $ride_id = params->{'ride_id'} || 'rid_' . new Data::UUID->create_str();
    my $title = params->{'title'};
    my $public = params->{'public'} || 0;

    if ( ! params->{'data_source'} ) {
        status 400;
        return 'no data_source type defined';
    }
    my $input_processor;
    my $ret;
    if ( params->{'data_source'} eq 'CycleAnalyst' ) {
        debug ( "Got CyclAnalyst type" );
        $input_processor = new MotoViz::CAFileProcessor();
        $ret = $input_processor->init ( $ride_id, params->{'ca_log_file'}, params->{'ca_gps_file'} );
        debug ( pp ( $input_processor ) );
    } elsif ( params->{'data_source'} eq 'TangoLogger' ) {
        debug ( "Got TangoLogger type" );
        $input_processor = new MotoViz::TangoLoggerProcessor();
        $ret = $input_processor->init ( $ride_id, params->{'tango_file'} );
        debug ( pp ( $input_processor ) );
    } else {
        die "bad data souce: " . params->{'data_source'};
    }
    if ( $ret->{'code'} <= 0 ) {
        status 400;
        return "Problem uploading file: " . pp ( $ret );
    }
    $ret = process_files ( $user_id, $ride_id, $input_processor, $title, $public );
    debug ( "fileProcessor returns: " . pp ( $ret ) );
    if ( $ret->{'code'} > 0 ) {
        status 201;
        header 'Location' => setting ( 'api_url' ) . '/v1/ride/' . $user_id . '/' . $ride_id;
        return;
    } else {
        status 500;
        warning 'Failed processing request.  processCAFiles returned: ' . pp ( $ret );
        return;
    }
};

# get '/v1/reprocess/:user_id/:ride_id' => sub {
#     my $ride_info = MotoViz::RideInfo::getRideInfo ( params->{'user_id'}, params->{'ride_id'} );
#     my $ret = process_files ( $user_id, $ride_id, $title, $public );
#     return_json $ret, { pretty => 1 };
# };

sub process_files {
    my $user_id = shift;
    my $ride_id = shift;
    my $input_processor = shift;
    my $title = shift;
    my $public = shift;
    my $ride_path = setting ( 'raw_log_dir' ) . '/' . $user_id . '/' . $ride_id;
    my $output_processor = new MotoViz::OutputProcessor();
    $output_processor->init ( $user_id, $ride_id, $title, $public, $input_processor );
    return $output_processor->generateOutputFile ( $ride_path . '/motoviz_output.out' );
};


sub fetch_points_average {
    my $ride_info = shift;
    my $limit_points = shift;
    my $metrics = shift;
    
    my $points_count = $ride_info->{'points_count'};
    my $fh;
    my $ride_file = setting ( 'raw_log_dir' ) . '/' . $ride_info->{'user_id'} . '/' . $ride_info->{'ride_id'} . '/motoviz_output.out';
    my $points = [];
    my $should_fetch;

        #
        # $mod is the ( total number of points / ( limit_points - 1 ) ).
        # to figure out which points from the original set to put in the final set,
        # keep track of the last int ( $point_num / $mod ).  If the int value 
        # is different than the last one, include the point.  Otherwise,
        # discard the point.
        #
    my $mod = ( $limit_points ) ? $points_count / ( $limit_points ) : 0;
    my $lastInt = -1;
    my $count = 0;
    my $avgCount = 0;

    open ( $fh, $ride_file ) || die;
    my $data = {};
    my $sums = {};
    foreach my $metric ( @{$metrics} ) {
        $sums->{$metric} = 0;
        $data->{$metric} = [];
    }
    while ( my $line = <$fh> ) {
        $should_fetch = 0;
        $avgCount++;
        if ( $limit_points ) {
            my $tmp = int ( $count / $mod );
            if ( $tmp != $lastInt ) {
                $lastInt = $tmp;
                $should_fetch = 1;
            }
        } else {
            $should_fetch = 1;
        }

        my $raw_point = from_json ( $line );

        foreach my $metric ( @{$metrics} ) {
            $sums->{$metric} += ( $raw_point->{$metric} ) ? $raw_point->{$metric} : 0;
        }

        my $time = $raw_point->{'time'} * 1000;
        push ( @{$data->{'lat'}}, [ $time, ( $raw_point->{'lat'} ) ? $raw_point->{'lat'} + 0 : 0 ] );
        push ( @{$data->{'lon'}}, [ $time, ( $raw_point->{'lon'} ) ? $raw_point->{'lon'} + 0 : 0 ] );
        if ( $should_fetch ) {
            #debug ( "avgCount: " . $avgCount );
            foreach my $metric ( @{$metrics} ) {
                if ( ( $metric ne 'lat' ) && ( $metric ne 'lon' ) ) {
                    my $avg = $sums->{$metric} / $avgCount;
                    #debug ( $metric . ', ' . $sums->{$metric} . ', avgCount: ' . $avgCount . ', avg: ' . $avg );
                    push ( @{$data->{$metric}}, [ $time, ( $avg ) ? $avg + 0 : 0 ] );
                }
            }
            foreach my $metric ( @{$metrics} ) {
                $sums->{$metric} = 0;
            }
            $avgCount = 0;
        }
        $count++;
    }
    return $data;
}

sub fetch_points_instant {
    my $ride_info = shift;
    my $limit_points = shift;
    
    my $points_count = $ride_info->{'points_count'};
    my $fh;
    my $ride_file = setting ( 'raw_log_dir' ) . '/' . $ride_info->{'user_id'} . '/' . $ride_info->{'ride_id'} . '/motoviz_output.out';
    my $points = [];
    my $should_fetch;

        #
        # $mod is the ( total number of points / ( limit_points - 1 ) ).
        # to figure out which points from the original set to put in the final set,
        # keep track of the last int ( $point_num / $mod ).  If the int value 
        # is different than the last one, include the point.  Otherwise,
        # discard the point.
        #
    my $mod = ( $limit_points ) ? $points_count / ( $limit_points ) : 0;
    my $lastInt = -1;
    my $count = 0;

    open ( $fh, $ride_file ) || die;
    while ( my $line = <$fh> ) {
        $should_fetch = 0;
        if ( $limit_points ) {
            my $tmp = int ( $count / $mod );
            if ( $tmp != $lastInt ) {
                $lastInt = $tmp;
                $should_fetch = 1;
            }
        } else {
            $should_fetch = 1;
        }

        if ( $should_fetch ) {
            my $raw_point = from_json ( $line );
            push ( @{$points}, $raw_point );
        }
        $count++;
    }
    return $points;
}

true;
