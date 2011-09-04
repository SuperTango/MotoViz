package UIRoutes;
use Dancer ':syntax';
use Dancer::Plugin::DBIC;
use Data::Dump qw( pp );
use Data::UUID;
use File::Path;
use LWP::UserAgent;

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
    if ( ! ensure_logged_in() ) {
        return;
    }
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
};

get '/rides' => sub {
    if ( my $login_page = ensure_logged_in() ) {
        return $login_page;
    }
    my $url = setting ( "motoviz_url" ) . '/v1/rides/' . session ( 'user' )->{'user_id'};
    debug ( "URL: " . $url );
    my $ua = LWP::UserAgent->new;
    my $response = $ua->get ( $url );
    debug ( "response status: " . $response->status_line );
    if ( $response->is_success ) {
        my $ride_infos = from_json ( $response->decoded_content );
        debug ( $ride_infos );
        debug ( pp ( $ride_infos ) );
        template 'list_rides.tt', {
            user => session ( 'user' ),
            ride_infos => $ride_infos,
        };
    } else {
        if ( $response->code() == 404 ) {
            debug ( "no rides for this user." );
        } else {
            debug ( "internal error" );
        }
    }
};

get '/viewer/:ride_id' => sub {
    if ( my $login_page = ensure_logged_in() ) {
        return $login_page;
    }
    my $ride_info_db = schema->resultset('Ride')->find({ user_id => session('user')->{'user_id'}, ride_id => params->{'ride_id'} });
    if ( ! $ride_info_db ) {
        status 'not_found';
        return;
    }
    my %cols = $ride_info_db->get_columns;
    template 'ride_viewer.tt', {
        user_id => session('user')->{'user_id'},
        ride_id => params->{'ride_id'},
        title => "Ride on " . localtime ( int ( $cols{'time_start'} ) ),
    }, { layout => undef };
};


sub ensure_logged_in {
    if ( ! session('user') ) {
        debug ( 'not logged in, setting redirect to ' . request->path );
        session 'original_destination' => request->path;
        return template 'login.tt', {
            'err' => 'Please login to perform your requested action.',
        };
    } else {
        return undef;
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
