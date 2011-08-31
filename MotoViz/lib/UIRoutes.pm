package MotoViz;
use Dancer ':syntax';
use Dancer::Plugin::Database;
use MotoViz::User;
use Data::Dump qw( pp );
use Data::UUID;
use File::Path;

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
        my $ride_id = params->{'ride_id'} || 'ride_' . new Data::UUID->create_str();
        my $ride_path = setting ( 'raw_log_dir' ) . '/' . session ('user')->{'uid'} . '/' . $ride_id;
        my $ca_log_file = request->upload ( 'ca_log_file' );
        my $ca_gps_file = request->upload ( 'ca_gps_file' );
        debug ( 'ride_id: ' . $ride_id );
        debug ( 'got ca_log_file: ' . pp ( $ca_log_file ) );
        debug ( 'got ca_gps_file: ' . pp ( $ca_gps_file ) );
        move_upload ( $ca_log_file, $ride_path );
        move_upload ( $ca_gps_file, $ride_path );
    }
};

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
    $upload->link_to ( $path . '/' . $filename );
    unlink ( $upload->tempname );
}


true;
