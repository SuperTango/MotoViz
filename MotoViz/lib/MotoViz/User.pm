package MotoViz::User;

use strict;
use warnings;
use Dancer qw(:syntax);
use Crypt::Eksblowfish::Bcrypt qw(bcrypt);
use Dancer::Plugin::Database;
use Data::Dump qw( pp );
use MIME::Base64;
use Data::UUID;

sub new {
    my $class = shift;
    my $self = {};
    $self->{'ready'} = 0;
    bless $self, $class;
    return $self;
}

sub createFromCredentials {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    my $email = shift;
    my $password = shift;
    my $row = database->quick_select ( 'users', { email => $email });
    debug ( pp ( $row ) );
    if ( ! $row ) {
        return undef;
    }

    my $saved_bcrypt_pw = $row->{'pass'};
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
        while ( my ( $key, $value ) = each ( %{$row} ) ) {
            $self->{$key} = $value;
        }
        return $self;
    } else { 
        debug "NOT matched";
        return undef;
    }
}

1;
