package MotoViz::UserStore;

use strict;
use warnings;
use Dancer qw(:syntax);
use Crypt::Eksblowfish::Bcrypt qw(bcrypt);
use Data::Dump qw( pp );
use MIME::Base64;
use Data::UUID;
use MotoViz::RESTHelper;

sub new {
    my $class = shift;
    my $pw_file = shift;
    my $self = {};
    $self->{'pw_file'} = $pw_file;
    if ( ! -f $pw_file ) {
        open ( my $fh, '>', $pw_file ) || die;
        print $fh "{}\n";
        close ( $fh );
    }

    bless $self, $class;
    return $self;
}


sub getUserFromEmail {
    my $self = shift;
    my $email = shift;
    my $ret = $self->_readPWFile();
    if ( $ret->{'code'} <= 0 ) {
        error ( 'Cannot read users file: ' . pp ( $ret ) );
        return $ret;
    }
    my $user_entries = $ret->{'data'};
    while ( my ( $uuid, $user ) = each ( %{$user_entries} ) ) {
        if ( lc ( $user->{'email'} ) eq lc ( $email ) ) {
            return { code => 1, data => $user };
        }
    }
    return { code => 1, data => undef };
}

sub getUserFromCredentials {
    my $self = shift;
    my $email = shift;
    my $password = shift;
    my $ret = $self->getUserFromEmail ( $email );
    if ( $ret->{'code'} <= 0 ) {
        return $ret;
    }

    my $user = $ret->{'data'};
    if ( ! $user ) {
        return $ret;
    }

    debug ( 'name: ' . $user->{'name'} );

    my $saved_bcrypt_pw = $user->{'pass'};
    debug ( "pw:                $password" );
    debug ( "saved_bcrypt_pw:   $saved_bcrypt_pw" );

    #regex for the blowfish hash id and the 22 char salt
    my ( $id_salt, $bcrypt_hashed_pw ) = $saved_bcrypt_pw =~ m#^(\$2a?\$\d{2}\$[A-Za-z0-9+\\.]{22})(.*)#;
        # 22 is shown, may be 53 on some systems?
    debug ( "id_salt:           $id_salt" );
    debug ( "bcrypt_hashed_pw   $bcrypt_hashed_pw" );
        
    my $new_bcrypt_pw =  bcrypt($password, $id_salt);
    debug ( "new_bcrypt_pw:     $new_bcrypt_pw" );
    debug ( "saved_bcrypt_pw:   $saved_bcrypt_pw" );

    if ( $new_bcrypt_pw eq $id_salt.$bcrypt_hashed_pw ) {
        debug "matched";
        return { code => 1, data => $user };
    } else { 
        debug "NOT matched";
        return { code => 1, data => undef };
    }
}

sub updateUser {
    my $self = shift;
    my $user = shift;

    if ( ! $user ) {
        return { code => -1, message => 'no user specified to updateUser' };
    }
    if ( $user->{'password_plaintext'} ) {
        my $id_salt = '$2a$05$';
        my $salt = '';
        for ( my $i = 0; $i < 20; $i++ ) {
            $salt .= ('A'..'Z', 'a'..'z')[rand 52];
        }
        $salt .= 'Au';
        debug ( 'setting new salt: ' . $salt );
        $id_salt .= $salt;
        my $hashed =  bcrypt ( $user->{'password_plaintext'}, $id_salt );
        if ( ! $hashed ) {
            return { code => -1, message => 'bcrypt failed! id_salt: ' .  $id_salt };
        }
        debug ( 'got good new encrypted pw: ' . $hashed );
        $user->{'pass'} = $hashed;
        delete $user->{'password_plaintext'};
    }
    debug ( 'updateUser on user: ' . pp ( $user ) );
    my $ret = _validateUser ( $user );
    debug ( "_validateUser returns: " . pp ( $ret ) );
    if ( $ret->{'code'} <= 0 ) {
        return $ret;
    }
    debug ( 'updateUser on user: ' . pp ( $user ) );

    $ret = $self->_readPWFile();
    if ( $ret->{'code'} <= 0 ) {
        error ( 'Cannot read users file: ' . pp ( $ret ) );
        return $ret;
    }
    my $user_entries = $ret->{'data'};

    if ( ! $user->{'user_id'} ) {
        return { code => -1, message => 'no user_id specified for the user: ' . pp ( $user ) };
    }
    $user_entries->{$user->{'user_id'}} = $user;
    $ret = $self->_updatePWFile ( $user_entries );
    if ( $ret->{'code'} <= 0 ) {
        return $ret;
    } else {
        return { code => 1, message => 'success' };
    }
}

sub _validateUser {
    my $user = shift;
    my @errors;
    if ( ! $user ) {
        return { code => -1, message => 'No user provided' };
    }

    foreach my $field ( qw( user_id name email pass timezone ) ) {
        if ( ( ! $user->{$field} ) || ( $user->{$field} =~ /^\s*$/ ) ) {
            push ( @errors, "The '" . $field . "' cannot be empty" );
        }
    }
    if ( @errors ) {
        return { code => 0, message => join ( ', ', @errors ) };
    } else {
        return { code => 1, message => 'success' };
    }
}

sub _updatePWFile {
    my $self = shift;
    my $user_entries = shift;
    my $pw_file = setting ( 'password_file' );
    my $ret = MotoViz::RESTHelper::writeToFile ( $pw_file, $user_entries );
    if ( $ret->{'code'} <= 0 ) {
        return $ret;
    }
    return { code => 1, message => 'success' };
}


sub _readPWFile {
    my $self = shift;
    my $pw_file = setting ( 'password_file' );
    my $ret = MotoViz::RESTHelper::readFromFile ( $pw_file );
    if ( $ret->{'code'} <= 0 ) {
        return $ret;
    }

    my $pw_data = $ret->{'data'};
    return { code => 1, data => $pw_data };
}

1;
