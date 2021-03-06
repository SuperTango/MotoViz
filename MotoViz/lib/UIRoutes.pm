package UIRoutes;
use Dancer ':syntax';
use Data::Dump qw( pp );
use Data::UUID;
use File::Path;
use LWP::UserAgent;
use HTTP::Request;
use HTML::Entities;
use Captcha::reCAPTCHA;

use MotoViz::UserStore;

our $VERSION = '0.1';

my $acceptable_emails = {
    'kginaven@gmail.com' => 1,
    'elec.bike@gmail.com' => 1,
    'altitude@funkware.com' => 1,
    'tango@funkware.com' => 1,
    'tango1@funkware.com' => 1,
    'tango2@funkware.com' => 1,
    'daveh225@acsalaska.net' => 1,
};

hook 'before' => sub {
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
    my $captcha = Captcha::reCAPTCHA->new;
    my $captcha_html = $captcha->get_html("6Ldm0skSAAAAAEw6Z_j9U4-LWerS33XQFMTTCb3Z");
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

        my $result = $captcha->check_answer( '6Ldm0skSAAAAAIAFs_w8vA_HjZrLkmDq9XXaIu4C', request->remote_address, params->{'recaptcha_challenge_field'}, params->{'recaptcha_response_field'} );
        if ( ! $result->{is_valid} ) {
            push ( @errors, 'The captcha response was incorrect. Please try again' );
        }

        my $ret = $userStore->getUserFromEmail ( params->{'email'} );
        if ( $ret->{'code'} > 0 ) {
            if ( $ret->{'data'} ) {
                push ( @errors, "A user with the specified email address already exists" );
            }
        }

        if ( ! $acceptable_emails->{params->{'email'}} ) {
            @errors = ( "Sorry, this user is not allowed to register at this time. Please contact Alex for more information" );
        }

        if ( @errors ) {
            return motoviz_template 'register_form.tt', { captcha_html => $captcha_html, errors => \@errors, user => $user };
        }

        $user->{'password_plaintext'} = $user->{'password1'};
        $user->{'user_id'} = 'uid_' . new Data::UUID->create_str();
        $user->{'member_since'} = time + 0;
        delete $user->{'password1'};
        delete $user->{'password2'};
        $ret = $userStore->updateUser ( $user );
        if ( $ret->{'code'} == 0 ) {
            log_error ( 'internal validation failed when registering user: ' . pp ( $user ) );
            return motoviz_template 'register_form.tt', { captcha_html => $captcha_html, user => $user, errors => [ 'validation failed' ] };
        } elsif ( $ret->{'code'} < 0 ) {
            my $eid = log_error ( 'internal error when registering user: ' . pp ( $user ) );
            return motoviz_template 'register_form.tt', { captcha_html => $captcha_html, user => $user, errors => [ 'internal error: ' . $eid ] };
        }

        session 'user' => $user;
        motoviz_template 'indexnew.tt';

    } else {
        return motoviz_template 'register_form.tt', { captcha_html => $captcha_html };
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
    my $visibility = params->{'visibility'} || 'private';
    my $input_data_type = params->{'input_data_type'};
    my $ca_log_file = request->upload ( 'ca_log_file' );
    my $ca_gps_file = request->upload ( 'ca_gps_file' );
    my $tango_file = request->upload ( 'tango_file' );
    my $url = setting ( "motoviz_api_url" ) . '/v1/ride/' . session ( 'user' )->{'user_id'};
    my $ua = LWP::UserAgent->new;
    my $ret;

    my @errors;
    my $error_code = 400;;
    
    if ( ! $title ) {
        push ( @errors, 'Title must be provided.' );
    }

    my $rest_params = {
        ride_id => $ride_id,
        title => $title,
        visibility => $visibility,
    };

    if ( ! $input_data_type ) {
        push ( @errors, 'The "Data Format" must be provided' );

    } elsif ( $input_data_type eq 'CycleAnalyst' ) {
        if ( ( ! $ca_log_file ) || ( ! $ca_gps_file ) ) {
            push ( @errors, 'Both the CycleAnalyst Log and CycleAnalyst GPS files must be provided.' );
        } else {
            debug ( 'move_upload ( ' . $ca_log_file . ', ' . $ride_path );
            $ret = move_upload ( $ca_log_file, $ride_path );
            debug ( 'ret from move_upload: ' . pp ( $ret ) );
            if ( $ret->{'code'} <= 0 ) {
                my $eid = log_error ( 'Upload processing failed' );
                push ( @errors, 'An internal error occurred (' . $eid . ')' );
                $error_code = 500;
            } else {
                $ca_log_file = $ret->{'full_file'};
            }

            $ret = move_upload ( $ca_gps_file, $ride_path );
            if ( $ret->{'code'} <= 0 ) {
                my $eid = log_error ( 'Upload processing failed' );
                push ( @errors, 'An internal error occurred (' . $eid . ')' );
                $error_code = 500;
            } else {
                $ca_gps_file = $ret->{'full_file'};
            }

            $rest_params->{'input_data_type'} = "CycleAnalyst";
            $rest_params->{'ca_log_file'} = $ca_log_file;
            $rest_params->{'ca_gps_file'} = $ca_gps_file;
        }
    } elsif ( $input_data_type eq 'TangoLogger' ) {
        if ( ! $tango_file ) {
            push ( @errors, 'The Tango Log file must be provided.' );
        } else {
            $ret = move_upload ( $tango_file, $ride_path );
            if ( $ret->{'code'} <= 0 ) {
                my $eid = log_error ( 'Upload processing failed' );
                push ( @errors, 'An internal error occurred (' . $eid . ')' );
                $error_code = 500;
            } else {
                $tango_file = $ret->{'full_file'};
            }
            $rest_params->{'input_data_type'} = "TangoLogger";
            $rest_params->{'tango_file'} = $tango_file;
        }
    } else {
        warning ( "input data type from user is: " . $input_data_type );
        push ( @errors, 'The "Data Format" provided was invalid' );
        return "Bad request, input data type is bad";
    }
    if ( @errors ) {
        status ( $error_code );
        return motoviz_template 'new_upload.tt', { errors => \@errors };
    }

    debug ( 'ride_id: ' . $ride_id );
    debug ( 'input_data_type: ' . $input_data_type );
    debug ( 'got ca_log_file: ' . pp ( $ca_log_file ) );
    debug ( 'got ca_gps_file: ' . pp ( $ca_gps_file ) );
    debug ( 'got tango_file: ' . pp ( $tango_file ) );
    debug ( 'title' . $title );
    debug ( 'visibility' . $visibility );

    my $response = $ua->post ( $url, $rest_params );
    debug ( "response from API server for URL: $url, status: " . $response->status_line );
    debug ( "response data: " . pp ( $response ));
    debug ( "ride_id: " . $ride_id );
    if ( $response->code == 201 ) {
        motoviz_template 'ride_viewer_client.tt', {
            user_id => session('user')->{'user_id'},
            ride_id => $ride_id,
            title => $title,
        };
    } elsif ( $response->code == 400 )  {
        push ( @errors, $response->content );
        return motoviz_template 'new_upload.tt', { errors => \@errors };
    } else {
        my $eid = log_error ( 'Failed posting upload data to API server: ' . pp ( $response ) );
        push ( @errors, 'Failed when trying to save the upload data (' . $eid . ')' );
        return motoviz_template 'new_upload.tt', { errors => \@errors };
    }

};

sub get_ride_infos {
    my $user_id = shift;

    my $url = setting ( "motoviz_api_url" ) . '/v1/ride';
    if ( $user_id ) {
        $url .= '/' . $user_id;
    }
    debug ( "URL: " . $url );
    my $ua = LWP::UserAgent->new;
    my $response = $ua->get ( $url );
    debug ( "response status: " . $response->status_line );
    if ( $response->is_success ) {
        my $ride_infos = from_json ( $response->decoded_content );
        my @sorted_ride_infos = sort { $a->{'time_start'} <=> $b->{'time_start'} } ( @{$ride_infos} );
        debug ( pp ( \@sorted_ride_infos ) );
        return { code => 1, response_code => 200, data => \@sorted_ride_infos };
    } elsif ( $response->code == 404 ) {
        return { code => 1, response_code => 200, data => [] };
    } else {
        return { code => 0, response_code => $response->code() };
    }
}

get '/my_rides' => sub {
    if ( my $login_page = ensure_logged_in() ) {
        return $login_page;
    }
    return motoviz_template 'list_rides.tt', {
        user => session ( 'user' ),
        rides_url => setting ( "motoviz_ui_url" ) . '/v1/my_rides',
    };
};

get '/public_rides' => sub {
    return motoviz_template 'list_public_rides.tt', {
        user => session ( 'user' ),
        rides_url => setting ( "motoviz_ui_url" ) . '/v1/public_rides',
    };
};

get '/v1/points_client/:user_id/:ride_id' => sub {
    my $ride_id = params->{'ride_id'};
    my $user_id = params->{'user_id'};
    my $ride_path = setting ( 'raw_log_dir' ) . '/' . $user_id . '/' . $ride_id;
    my $combined_json = $ride_path . '/combined.json';
    my $fh;
    #debug ( "combined_json: " . $combined.json );
    return send_file ( $combined_json, content_type => 'application/json', system_path => 1 );
};

get '/v1/metric/:user_id/:ride_id/:metric' => sub {
    my $ride_id = params->{'ride_id'};
    my $user_id = params->{'user_id'};
    my $metric = params->{'metric'};
    my $ride_path = setting ( 'raw_log_dir' ) . '/' . $user_id . '/' . $ride_id;
    my $metric_file = $ride_path . '/metric-' . $metric . '.json';
    if ( ! -f $metric_file ) {
        status 404;
        return "metric not found";
    }
    return send_file ( $metric_file, content_type => 'application/json', system_path => 1 );
};

sub return_rest_rides {
    my $ret = shift;
    my $data;
    if ( $ret->{'code'} == 1 ) {
        $data = { aaData => $ret->{'data'} };
        content_type 'application/json';
        return to_json ( $data );
    } else {
        if ( $ret->response_code() == 404 ) {
            content_type 'application/json';
            return to_json ( [] );
        } else {
            status ( 500 );
            debug ( "internal error" );
        }
    }
}

get '/v1/my_rides' => sub {
    if ( my $login_page = ensure_logged_in() ) {
        status 401;
        return "Access Denied!";
    }
    my $ret = get_ride_infos ( session ( 'user' )->{'user_id'} );
    return return_rest_rides ( $ret );

};

get '/v1/public_rides' => sub {
    my $ret = get_ride_infos();
    return return_rest_rides ( $ret );
};

any [ 'get', 'post' ] => '/v1/update_ride/:ride_id' => sub {
    if ( my $login_page = ensure_logged_in() ) {
        status 401;
        return "Access Denied!";
    }
    my $new_title = params->{'new_title'};
    my $new_visibility = params->{'new_visibility'} || 'private';
    debug ( pp ( params ) );
    my $url = setting ( "motoviz_api_url" ) . '/v1/ride/' . session ( 'user' )->{'user_id'} . '/' . params->{'ride_id'};
    my $request = HTTP::Request->new ( 'PUT', $url );
    $request->header ( "Content-Type" => "application/json" );
    $request->content ( to_json ( { "title" => $new_title, visibility => $new_visibility } ) );
        # TODO: Should really do more validation here.
    my $ua = LWP::UserAgent->new;
    my $response = $ua->request ( $request );
    debug ( pp ( $response ) );
    status ( $response->code );
};

get '/v1/delete_ride/:ride_id' => sub {
    if ( my $login_page = ensure_logged_in() ) {
        status 401;
        return "Access Denied!";
    }
    my $url = setting ( "motoviz_api_url" ) . '/v1/ride/' . session ( 'user' )->{'user_id'} . '/' . params->{'ride_id'};
    debug ( 'calling update url: ' . $url );
    my $request = HTTP::Request->new ( 'DELETE', $url );
    my $ua = LWP::UserAgent->new;
    my $response = $ua->request ( $request );
    debug ( pp ( $response ) );
    status ( $response->code );
};

get '/viewer/:user_id/:ride_id' => sub {
    my $url = setting ( "motoviz_api_url" ) . '/v1/ride/' . params->{'user_id'} . '/' . params->{'ride_id'};
    debug ( "URL: " . $url );
    my $ua = LWP::UserAgent->new;
    my $response = $ua->get ( $url );
    debug ( "response status: " . $response->status_line );
    if ( $response->is_success ) {
        my $ride_info = from_json ( $response->decoded_content );
        if ( ! $ride_info->{'visibility'} ) {
            $ride_info->{'visibility'} = 'private';
        }
        if ( $ride_info->{'visibility'} eq 'private' ) {
            if ( my $login_page = ensure_logged_in() ) {
                return $login_page;
            }
            if ( params->{'user_id'} ne session('user')->{'user_id'} ) {
                return "not authorized";
            }
        }
        debug ( pp ( $ride_info ) );
        motoviz_template 'ride_viewer_client.tt', {
            user_id => params->{'user_id'},
            ride_id => params->{'ride_id'},
            title => $ride_info->{'title'},
        };
    } else {
        if ( $response->code() == 404 ) {
            debug ( "no rides for this user." );
            return send_error ("not found", 404 );
        } else {
            debug ( "internal error" );
            return send_error ("internal error", 500 );
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
    debug ( "upload: " . $upload->filename );
    $filename =~ s/^\.+//;
    $filename =~ s/\/+//g;

    eval { mkpath ( $path ) };
    if ( $@ ) {
        error ( 'failed to make ride directory: ' . $path );
        return { code => -1, message => 'failed to make ride directory: ' . $path };
    }
    my $full_file = $path . '/' . $filename;
    debug ( "upload: $full_file" );
    if ( ! $upload->link_to ( $full_file ) ) {
        if ( ! $upload->copy_to ( $full_file ) ) {
            return { code => -1, message => 'upload->link_to and copy_to failed: ' . $! };
        }
    }
    unlink ( $upload->tempname );
    return { code => 1, message => 'success', full_file => $full_file };
}


sub log_error {
    my $msg = shift;
    my $eid = new Data::UUID->create_str();
    error ( Carp::longmess ( 'EID:' . $eid . ': ' . $msg ) );
    return $eid;
}

true;
