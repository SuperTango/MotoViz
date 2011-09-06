package UIRoutes;
use Dancer ':syntax';
use Data::Dump qw( pp );
use Data::UUID;
use File::Path;
use LWP::UserAgent;

use MotoViz::UserStore;

our $VERSION = '0.1';

before sub {
    debug ( pp ( session ) );
    if ( request->path ne '/login' ) {
        if ( session ( 'original_destination' ) ) {
            debug ( 'not going to login, but original_destination set.  deleting original_destination from session' );
            session 'original_destination' => undef;
        }
    }
    if ( session ( 'user' ) ) {
        session 'last_visit' => time;
    }
};

sub motoviz_template {
    my $template = shift;
    my $template_options = shift;
    my $engine_options = shift;
    if ( ! $template_options ) {
        $template_options = {};
    }
    $template_options->{'ui_url'} = setting ( 'motoviz_ui_url' );
    $template_options->{'api_url'} = setting ( 'motoviz_api_url' );
    template $template, $template_options, $engine_options;
}

get '/createuser1' => sub {
    my $user = {
        user_id => 'uid_E0740DAE-D361-11E0-B80A-910AC869DD8D',
        name => 'Alex Tang',
        password_plaintext => 'foobar',
        email => 'altitude@funkware.com',
        timezone => 'America/Los_Angeles',
    };
    my $userStore =  MotoViz::UserStore->new ( setting ( 'password_file' ) );
    my $ret = $userStore->updateUser ( $user );
};

get '/' => sub {
    motoviz_template 'indexnew.tt';
};

any ['get', 'post'] => '/login' => sub {
    my $err;
 
    if ( request->method() eq "POST" ) {
        my $userStore =  MotoViz::UserStore->new ( setting ( 'password_file' ) );
        if ( ! $userStore ) {
            my $eid = log_error ( 'Failed getting user store' );
            status ( 500 );
            return 'An internal error occurred (' . $eid . ')';
        }

        my $ret = $userStore->getUserFromCredentials ( params->{'email'}, params->{'password'} );
        if ( $ret->{'code'} <= 0 ) {
            my $eid = log_error ( 'error when getting users from credentials: ' . pp ( $ret ) );
            status ( 500 );
            return 'An internal error occurred (' . $eid . ')';
        }

        my $user = $ret->{'data'};
        if ( ! $user ) {
            $err = 'Login Failed.  Invalid or unknown email/password combination';
        } else {
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
    motoviz_template 'login.tt', { 
        'err' => $err,
    };
};

any ['get', 'post'] => '/register' => sub {
    if ( session('user') ) {
        return motoviz_template 'indexnew.tt', { message => 'You are already logged in, registration not neeed or allowed' };
    }
    if ( request->method() eq "POST" ) {
        my $userStore =  MotoViz::UserStore->new ( setting ( 'password_file' ) );
        my $user = {};
        my @errors;
        foreach my $field ( qw( name email password1 password2 timezone ) ) {
            if ( ( ! params->{$field} ) || ( params->{$field} =~ /^\s*$/ ) ) {
                push ( @errors, "The '" . $field . "' field must be provided" );
            } else {
                $user->{$field} = params->{$field};
            }
        }
        if ( ( ! params->{'password1'} ) || 
             ( ! params->{'password2'} ) ||
             ( params->{'password1'} ne params->{'password2'} ) ) {
            push ( @errors, "Both passwords must exist and, they must be the same." );
        }

        my $ret = $userStore->getUserFromEmail ( params->{'email'} );
        if ( $ret->{'code'} > 0 ) {
            if ( $ret->{'data'} ) {
                push ( @errors, "A user with the specified email address already exists" );
            }
        }

        if ( @errors ) {
            return motoviz_template 'register_form.tt', { errors => \@errors, user => $user };
        }

        $user->{'password_plaintext'} = $user->{'password1'};
        $user->{'user_id'} = 'uid_' . new Data::UUID->create_str();
        delete $user->{'password1'};
        delete $user->{'password2'};
        $ret = $userStore->updateUser ( $user );
        if ( $ret->{'code'} == 0 ) {
            log_error ( 'internal validation failed when registering user: ' . pp ( $user ) );
            return motoviz_template 'register_form.tt', { user => $user, errors => [ 'validation failed' ] };
        }

        session 'user' => $user;
        motoviz_template 'indexnew.tt';

    } else {
        motoviz_template 'register_form.tt';
    }
};

any ['get', 'post'] => '/update_registration' => sub {
    if ( my $login_page = ensure_logged_in() ) {
        return $login_page;
    }
    my $current_user = session('user');
    if ( request->method() eq "POST" ) {
        my $userStore =  MotoViz::UserStore->new ( setting ( 'password_file' ) );
        my $updated_user = { user_id => $current_user->{'user_id'} };
        my @errors;
        foreach my $field ( qw( name email timezone ) ) {
            if ( ( ! params->{$field} ) || ( params->{$field} =~ /^\s*$/ ) ) {
                push ( @errors, "The '" . $field . "' field must be provided" );
            } else {
                $updated_user->{$field} = params->{$field};
            }
        }

        if ( params->{'password1'} || params->{'password2'} || params->{'old_password'} ) {
            if ( ! params->{'old_password'} ) {
                push ( @errors, 'When resetting your password, the old password must be provided.' );
            }
            if ( ( ! params->{'password1'} ) || 
                 ( ! params->{'password2'} ) ||
                 ( params->{'password1'} ne params->{'password2'} ) ) {
                push ( @errors, "When resetting your password, Both passwords must exist and, they must be the same." );
            }

            if ( params->{'old_password'} ) {
                my $ret = $userStore->getUserFromCredentials ( $current_user->{'email'}, params->{'old_password'} );
                if ( $ret->{'code'} <= 0 ) {
                    my $eid = log_error ( 'error when getting users from credentials: ' . pp ( $ret ) );
                    status ( 500 );
                    return 'An internal error occurred (' . $eid . ')';
                }
                my $tmp_user = $ret->{'data'};
                if ( ! $tmp_user ) {
                    push ( @errors, "The old password was incorrect." );
                } else {
                    $updated_user->{'password_plaintext'} = params->{'password1'};
                }
            }

        } else {
            $updated_user->{'pass'} = $current_user->{'pass'};
        }

        my $ret = $userStore->getUserFromEmail ( params->{'email'} );
        if ( $ret->{'code'} > 0 ) {
            if ( $ret->{'data'} && $ret->{'data'}->{'user_id'} ne $current_user->{'user_id'} ) {
                push ( @errors, "An account with the specified email address already exists" );
            }
        }

        if ( @errors ) {
            return motoviz_template 'update_user_form.tt', { errors => \@errors, user => $updated_user };
        }

        $ret = $userStore->updateUser ( $updated_user );
        if ( $ret->{'code'} == 0 ) {
            log_error ( 'internal validation failed when updating user: ' . pp ( $updated_user ) );
            return motoviz_template 'update_user_form.tt', { user => $updated_user, errors => [ 'validation failed' ] };
        }

        session 'user' => $updated_user;
        motoviz_template 'indexnew.tt', { message => 'Account information successfully updated' };

    } else {
        motoviz_template 'update_user_form.tt', { user => $current_user };
    }
};

any ['get', 'post'] => '/logout' => sub {
    session->destroy;
    motoviz_template 'indexnew.tt';
};

any ['get', 'post'] => '/new_upload' => sub {
    if ( my $login_page = ensure_logged_in() ) {
        return $login_page;
    }
    debug ( "logged in!" );
    motoviz_template 'new_upload.tt';
};

post '/upload' => sub {
    if ( my $login_page = ensure_logged_in() ) {
        return $login_page;
    }
    my $ride_id = params->{'ride_id'} || 'rid_' . new Data::UUID->create_str();
    my $ride_path = setting ( 'raw_log_dir' ) . '/' . session ('user')->{'user_id'} . '/' . $ride_id;
    my $title = params->{'title'};
    my $public = params->{'public'} || 0;
    my $ca_log_file = request->upload ( 'ca_log_file' );
    my $ca_gps_file = request->upload ( 'ca_gps_file' );
    debug ( 'ride_id: ' . $ride_id );
    debug ( 'got ca_log_file: ' . pp ( $ca_log_file ) );
    debug ( 'got ca_gps_file: ' . pp ( $ca_gps_file ) );
    debug ( 'title' . $title );
    debug ( 'public' . $public );
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

    my $url = setting ( "motoviz_api_url" ) . '/v1/ride/' . session ( 'user' )->{'user_id'};
    my $ua = LWP::UserAgent->new;
    my $rest_params = {
        ride_id => $ride_id,
        title => $title,
        public => $public,
        data_source => "CycleAnalyst",
        ca_log_file => $ca_log_file,
        ca_gps_file => $ca_gps_file,
    };
    my $response = $ua->post ( $url, $rest_params );
    debug ( "response status: " . $response->status_line );
    debug ( "ride_id: " . $ride_id );
    if ( $response->code == 201 ) {
        motoviz_template 'ride_viewer.tt', {
            user_id => session('user')->{'user_id'},
            ride_id => $ride_id,
            title => $title,
        }, { layout => undef };
    }

};


get '/rides' => sub {
    if ( my $login_page = ensure_logged_in() ) {
        return $login_page;
    }
    my $url = setting ( "motoviz_api_url" ) . '/v1/ride/' . session ( 'user' )->{'user_id'};
    debug ( "URL: " . $url );
    my $ua = LWP::UserAgent->new;
    my $response = $ua->get ( $url );
    debug ( "response status: " . $response->status_line );
    if ( $response->is_success ) {
        my $ride_infos = from_json ( $response->decoded_content );
        debug ( $ride_infos );
        debug ( pp ( $ride_infos ) );
        motoviz_template 'list_rides.tt', {
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
    my $url = setting ( "motoviz_api_url" ) . '/v1/ride/' . session ( 'user' )->{'user_id'} . '/' . params->{'ride_id'};
    debug ( "URL: " . $url );
    my $ua = LWP::UserAgent->new;
    my $response = $ua->get ( $url );
    debug ( "response status: " . $response->status_line );
    if ( $response->is_success ) {
        my $ride_info = from_json ( $response->decoded_content );
        debug ( pp ( $ride_info ) );
        motoviz_template 'ride_viewer.tt', {
            user_id => session('user')->{'user_id'},
            ride_id => params->{'ride_id'},
            title => $ride_info->{'title'},
        }, { layout => undef };


    } else {
        if ( $response->code() == 404 ) {
            debug ( "no rides for this user." );
        } else {
            debug ( "internal error" );
        }
    }



};

sub ensure_logged_in {
    if ( ! session('user') ) {
        debug ( 'not logged in, setting redirect to ' . request->path );
        session 'original_destination' => request->path;
        return motoviz_template 'login.tt', {
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


sub log_error {
    my $msg = shift;
    my $eid = new Data::UUID->create_str();
    error ( 'EID:' . $eid . ': ' . $msg );
    return $eid;
}

true;
