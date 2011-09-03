package MotoViz;
use Dancer ':syntax';
use Dancer::Plugin::DBIC;
use Data::Dump qw( pp );
use Data::UUID;
use File::Path;
use JSON;

use MotoViz::User;
use MotoViz::CAFileProcessor;

our $VERSION = '0.1';

before sub {
    if ( request->path ne '/login' ) {
        if ( session ( 'original_destination' ) ) {
            debug ( 'not going to login, but original_destination set.  deleting original_destination from session' );
            session 'original_destination' => undef;
        }
    }
};

get '/' => sub {
    template 'indexnew.tt';
};

get '/test' => sub {
    my $users = schema->resultset('User')->find({ email => 'altitude@funkware.co2m' });
    debug ( 'dbic user: ' . ref ( $users ) );
    debug ( 'user: ' . pp ( $users ) );
    #debug ( 'name: ' . $users->name );
    #setting ( 'layout' => undef );
    template 'indexnew.tt';
};

get '/test2' => sub {
    my $caFileProcessor = new MotoViz::CAFileProcessor;
    $caFileProcessor->processCAFiles ( 'uid_E0740DAE-D361-11E0-B80A-910AC869DD8D',
                                       'rid_45ECB7CC-D433-11E0-BD6D-C4EC9AAFEDAC',
                                       '/funk/home/altitude/MotoViz/MotoViz/var/raw_log_data/uid_E0740DAE-D361-11E0-B80A-910AC869DD8D/rid_45ECB7CC-D433-11E0-BD6D-C4EC9AAFEDAC/CA_log0004 (04 Aug 2011 11 57 UTC).txt',
                                       '/funk/home/altitude/MotoViz/MotoViz/var/raw_log_data/uid_E0740DAE-D361-11E0-B80A-910AC869DD8D/rid_45ECB7CC-D433-11E0-BD6D-C4EC9AAFEDAC/GPS_log0004 (04 Aug 2011 11 57 UTC).txt',
                                       '/funk/home/altitude/MotoViz/MotoViz/var/raw_log_data/uid_E0740DAE-D361-11E0-B80A-910AC869DD8D/rid_45ECB7CC-D433-11E0-BD6D-C4EC9AAFEDAC/motoviz_output.out',
                                       );
    template 'indexnew.tt';
};

get '/hello/:name' => sub {
    template 'hello' => { number => 42 };
};

any ['get', 'post'] => '/login' => sub {
    my $err;
 
    my $user;
    if ( request->method() eq "POST" ) {
        $user =  MotoViz::User->createFromCredentials ( params->{'username'}, params->{'password'} );
        if ( ! $user ) {
            $err = 'Invalid username or password';
        } else {
            session 'logged_in' => true;
            session 'user' => $user;
            if ( session ( 'original_destination' ) ) {
                debug ( 'original destination set, doing a redirect.' );
                my $redirect_target = session ( 'original_destination' );
                return redirect $redirect_target;
            } else {
                return redirect '/';
            }
        }
    }
 
    # display login form
    template 'login.tt', { 
        'err' => $err,
        'add_entry_url' => uri_for('/add'),
        user => $user,
    };
};

any ['get', 'post'] => '/logout' => sub {
    session->destroy;
    template 'indexnew.tt';
};

any ['get', 'post'] => '/new_upload' => sub {
    if ( ! session('user') ) {
        debug ( 'not logged in, setting redirect to /new_upload' );
        session 'original_destination' => '/new_upload';
        template 'login.tt', {
            'err' => 'must be logged in'
        };
        #return redirect '/login';
    } else {
        template 'new_upload.tt';
    }
};

post '/upload' => sub {
    if ( ensure_logged_in() ) {
        my $ride_id = params->{'ride_id'} || 'rid_' . new Data::UUID->create_str();
        my $ride_path = setting ( 'raw_log_dir' ) . '/' . session ('user')->{'user_id'} . '/' . $ride_id;
        my $ca_log_file = request->upload ( 'ca_log_file' );
        my $ca_gps_file = request->upload ( 'ca_gps_file' );
        debug ( 'ride_id: ' . $ride_id );
        debug ( 'got ca_log_file: ' . pp ( $ca_log_file ) );
        debug ( 'got ca_gps_file: ' . pp ( $ca_gps_file ) );
        my $ret = move_upload ( $ca_log_file, $ride_path );
        if ( $ret->{'code'} <= 0 ) {
            # TODO: Error handling here.
        } else {
            $ca_log_file = $ret->{'full_file'};
        }

        $ret = move_upload ( $ca_gps_file, $ride_path );
        if ( $ret->{'code'} <= 0 ) {
            # TODO: Error handling here.
        } else {
            $ca_gps_file = $ret->{'full_file'};
        }

        my $caFileProcessor = new MotoViz::CAFileProcessor;
        $caFileProcessor->processCAFiles ( session ('user')->{'user_id'}, $ride_id,
                $ca_log_file, $ca_gps_file, $ride_path . '/motoviz_output.out' );
    }
};

get '/viewer/:user_id/:ride_id' => sub {
    my $ride_info_db = schema->resultset('Ride')->find({ user_id => params->{'user_id'}, ride_id => params->{'ride_id'} });
    if ( ! $ride_info_db ) {
        status 'not_found';
        return;
    }
    my %cols = $ride_info_db->get_columns;
    template 'ride_viewer.tt', {
        user_id => params->{'user_id'},
        ride_id => params->{'ride_id'},
        title => "Ride on " . localtime ( int ( $cols{'time_start'} ) ),
    }, { layout => undef };
};

#get qr#/v1/points/(uid_.*?)/(rid_.*?)/kjkjkj# => sub 
get '/v1/points/:user_id/:ride_id' => sub {
    my $ride_info_db = schema->resultset('Ride')->find({ user_id => params->{'user_id'}, ride_id => params->{'ride_id'} });
    if ( ! $ride_info_db ) {
        status 'not_found';
        return;
    }
    my $params = params;
    my $limit_points = params->{'limit_points'};
    my %cols = $ride_info_db->get_columns;
    my @metrics = $params->{'metrics'} || ( 'battery_volts', 'battery_amps', 'speed_gps', 'bearing', 'lat', 'lon'  );
    my $points = fetch_points ( \%cols, $limit_points );
    my $ret = {};
    foreach my $point ( @{$points} ) {
        foreach my $metric ( @metrics ) {
            my $time = $point->{'time'} * 1000;
            if ( ! exists $ret->{$metric} ) {
                $ret->{$metric} = [];
            }
            push ( @{$ret->{$metric}}, [ $time, ( $point->{$metric} ) ? $point->{$metric} + 0 : 0 ] );
        }
    }


    content_type 'application/json';
    return to_json ( $ret, { pretty => 1 } );
};

get '/v1/rides/:user_id/:ride_id' => sub {
    my $ride_info_db = schema->resultset('Ride')->find({ user_id => params->{'user_id'}, ride_id => params->{'ride_id'} });
    if ( ! $ride_info_db ) {
        status 'not_found';
        return;
    }
    my $params = params;
    my $limit_points = params->{'limit_points'};
    my %cols = $ride_info_db->get_columns;
    content_type 'application/json';
    return to_json ( \%cols, { pretty => 1 } );
};


sub fetch_points {
    my $ride_info = shift;
    my $limit_points = shift;
    my $json = JSON->new->allow_nonref;
    
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
            my $raw_point = $json->decode ( $line );
            push ( @{$points}, $raw_point );
        }
        $count++;
    }
    return $points;
}


sub ensure_logged_in {
    if ( ! session('user') ) {
        debug ( 'not logged in, setting redirect to ' . request->path );
        session 'original_destination' => request->path;
        template 'login.tt', {
            'err' => 'Please login to perform your requested action.',
        };
        return 0;
    } else {
        return 1;
    }
}

sub move_upload {
    my $upload = shift;
    my $path = shift;
    if ( ! $upload ) {
        return { code => 1, message => 'no upload file. no need to move' };
    }
    my $filename = $upload->filename;
    $filename =~ s/^\.+//;
    $filename =~ s/\/+//g;

    eval { mkpath ( $path ) };
    if ( $@ ) {
        error ( 'failed to make ride directory: ' . $path );
        return { code => -1, message => 'failed to make ride directory: ' . $path };
    }
    my $full_file = $path . '/' . $filename;
    $upload->link_to ( $full_file );
    unlink ( $upload->tempname );
    return { code => 1, message => 'success', full_file => $full_file };
}


true;
