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
    if ( ( exists params->{'pretty'} ) || ( exists params->{'sort'} ) ) {
        $options->{'pretty'} = 1;
        $options->{'canonical'} = 1;
    }
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
    $ride_info->{'ride_url'} = setting ( 'api_url' ) . '/v1/ride/' . params->{'user_id'} . '/' . $ride_info->{'ride_id'};
    $ride_info->{'points_url'} = setting ( 'api_url' ) . '/v1/points/' . params->{'user_id'} . '/' . $ride_info->{'ride_id'};
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

put '/v1/ride/:user_id/:ride_id' => sub {
    my $ride_info = MotoViz::RideInfo::getRideInfo ( params->{'user_id'}, params->{'ride_id'} );
    my $ride_info_new = from_json request->body;
    debug ( "Got here!" );
    debug ( pp ( $ride_info_new ) );
    if ( ! $ride_info ) {
        status 'not found';
        return 'not found';
    }

    my $new_title = $ride_info_new->{'title'};
    if ( $new_title ) {
        $ride_info->{'title'} = $new_title;
    }
    $ride_info->{'visibility'} = $ride_info_new->{'visibility'} || 'private';
    
    debug ( pp ( $ride_info ) );
    my $ret = MotoViz::RideInfo::updateRideInfo ( params->{'user_id'}, params->{'ride_id'}, $ride_info );
    if ( $ret ) {
        debug ( 'update ride info success' );
        status 204;
    } else {
        debug ( 'update ride info fail' );
        status 500;
    }
};

get '/v1/reset_rides' => sub {
    my $dh;
    my $raw_log_dir = setting ( 'raw_log_dir' );
    opendir ( $dh, setting ( 'raw_log_dir' ) ) || do {
        error ( 'Failed opening raw_log_dir: "' . $raw_log_dir . '". Error: ' . $! );
        return send_error ( 'Internal Error', 500 );
    };
    my $retVals = {};
    foreach my $user_id ( sort ( readdir ( $dh ) ) ) {
        next if ( $user_id !~ /^uid_[\w\-]/ );
        debug ( $user_id );
        my $ride_infos = MotoViz::RideInfo::getRideInfos ( $user_id );
        foreach my $ride_info ( @{$ride_infos} ) {
            if ( $ride_info && $ride_info->{'input_data_type'} ) {
                if ( $ride_info->{'public'} ) {
                    $ride_info->{'visibiity'} = 'public';
                } elsif ( ! $ride_info->{'visibility'} ) {
                    $ride_info->{'visibiity'} = 'private';
                }
                my $ret;
                if ( $ride_info->{'input_data_type'} eq 'CycleAnalyst' ) {
                    $ret = process_ride ( $ride_info->{'user_id'}, $ride_info->{'ride_id'}, $ride_info->{'title'}, $ride_info->{'visibility'}, $ride_info->{'input_data_type'}, [ $ride_info->{'input_data_source'}->{'ca_log_file'}, $ride_info->{'input_data_source'}->{'ca_gps_file'} ] );
                } elsif ( $ride_info->{'input_data_type'} =~ /^TangoLogger/ ) {
                    $ret = process_ride ( $ride_info->{'user_id'}, $ride_info->{'ride_id'}, $ride_info->{'title'}, $ride_info->{'visibility'}, $ride_info->{'input_data_type'}, [ $ride_info->{'input_data_source'}->{'tango_file'} ] );
                } 
                $retVals->{$ride_info->{'user_id'} . '/' . $ride_info->{'ride_id'}} = $ret;
            }
        }
    }
    status 200;
    return_json ( $retVals, { pretty => 1, canonical => 1 } );
};

post '/v1/ride/:user_id' => sub {
    my $user_id = params->{'user_id'};
    my $ride_id = params->{'ride_id'} || 'rid_' . new Data::UUID->create_str();
    my $title = params->{'title'};
    my $visibility = params->{'visibility'} || 'private';

    my $ret;

    if ( ! params->{'input_data_type'} ) {
        status 400;
        return 'no input_data_type type defined';
    } elsif ( ( params->{'input_data_type'} ne 'CycleAnalyst' ) && ( params->{'input_data_type'} !~ /^TangoLogger/ ) ) {
        status 400;
        warning ( 'input_data_type type: ' . params->{'input_data_type'} . ' is invalid.' );
        return 'Bad input_data_type type';
    }

    if ( params->{'input_data_type'} eq 'CycleAnalyst' ) {
        $ret = process_ride ( $user_id, $ride_id, $title, $visibility, params->{'input_data_type'}, [ params->{'ca_log_file'}, params->{'ca_gps_file'} ] );
    } elsif ( params->{'input_data_type'} =~ /^TangoLogger/ ) {
        $ret = process_ride ( $user_id, $ride_id, $title, $visibility, params->{'input_data_type'}, [ params->{'tango_file'}  ]);
    }
    if ( $ret->{'code'} > 0 ) {
        status 201;
        header 'Location' => setting ( 'api_url' ) . '/v1/ride/' . $user_id . '/' . $ride_id;
    } elsif ( $ret->{'code'} == 0 ) {
        status 400;
        return $ret->{'message'};
    } else {
        status 500;
        return 'internal error';
    }
};

sub process_ride {
    my $user_id = shift;
    my $ride_id = shift;
    my $title = shift;
    my $visibility = shift;
    my $input_data_type = shift;
    my $log_files = shift;
    debug ( 'ride_id: ' . $ride_id );

    my $input_processor;
    my $ret;
    if ( $input_data_type eq 'CycleAnalyst' ) {
        debug ( "Got CycleAnalyst type" );
        $input_processor = new MotoViz::CAFileProcessor();
        $ret = $input_processor->init ( $ride_id, $log_files->[0], $log_files->[1] );
        warning ( pp ( $ret ) );
    } elsif ( $input_data_type =~ /^TangoLogger/ ) {
        debug ( "Got TangoLogger type" );
        $input_processor = new MotoViz::TangoLoggerProcessor();
        $ret = $input_processor->init ( $ride_id, , $log_files->[0] );
    } else {
        my $ret = { code => -2, message => "bad data souce: " . $input_data_type };
        warning ( pp ( $ret ) );
        return $ret;
    }
    if ( $ret->{'code'} <= 0 ) {
            # note, message goes to user
        my $ret = { code => 0, message => $ret->{'message'} };
        warning ( pp ( $ret ) );
        return $ret;
    }
    $ret = process_input_files ( $user_id, $ride_id, $input_processor, $title, $visibility );
    debug ( "fileProcessor returns: " . pp ( $ret ) );
    if ( $ret->{'code'} > 0 ) {
        return { code => 1, message => 'success' };
    } else {
        my $ret = { code => -1, message => 'Failed processing request.  Process files returned: ' . pp ( $ret ) };
        error pp ( $ret );
        return $ret;
    }
};

sub process_input_files {
    my $user_id = shift;
    my $ride_id = shift;
    my $input_processor = shift;
    my $title = shift;
    my $visibility = shift;
    my $ride_path = setting ( 'raw_log_dir' ) . '/' . $user_id . '/' . $ride_id;
    my $output_processor = new MotoViz::OutputProcessor();
    $output_processor->init ( $user_id, $ride_id, $title, $visibility, $input_processor );
    return $output_processor->generateOutputFiles ( $ride_path );
};

true;
