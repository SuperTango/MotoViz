package MotoViz::RideInfo;
use strict;
use warnings;
use Dancer qw( :syntax );
use Data::Dump qw( pp );

sub getRideInfos {
    my $user_ids = shift;
    my $public_visibility_only = shift;
    my $users_path = setting ( 'raw_log_dir' );
    debug ( pp ( $user_ids ) );
    if ( ! $user_ids || ( ! @{$user_ids} ) ) {
        my $dirFH;
        if ( ! opendir ( $dirFH, $users_path ) ) {
            error ( 'Couldn\'t open raw log dir: ' . $users_path . '. Error: ' . $! );
            return undef;
        }
        my @user_ids = sort ( grep ( /^uid_/, readdir ( $dirFH ) ) );
        $user_ids = \@user_ids;
        debug ( "user_ids: " . pp ( $user_ids ) );
    }

    my $ride_infos = [];
    foreach my $user_id ( @{$user_ids} ) {
        debug ( "user: $user_id" );
        my $user_ride_infos = getUserRideInfos ( $user_id, $public_visibility_only );
        if ( $user_ride_infos ) {
            push ( @{$ride_infos}, @{$user_ride_infos} );
        }
    }
    return $ride_infos;
}

sub getUserRideInfos {
    my $user_id = shift;
    my $public_visibility_only = shift;
    my $user_path = setting ( 'raw_log_dir' ) . '/' . $user_id;
    my $dirFH;
    if ( ! opendir ( $dirFH, $user_path ) ) {
        return undef;
    }
    my $user_ride_infos = [];
    foreach my $ride_id ( sort ( readdir ( $dirFH ) ) ) {
        next if ( $ride_id !~ /^rid_/ );
        my $ride_info = getRideInfo ( $user_id, $ride_id );
        if ( $ride_info ) {
            if ( ( $public_visibility_only && ( $ride_info->{'visibility'} eq 'public' ) ) || ! $public_visibility_only ) {
                $ride_info->{'ride_id'} = $ride_id;
                push ( @{$user_ride_infos}, $ride_info );
            }
        }
    }
    return $user_ride_infos;
}

sub getRideInfo {
    my $user_id = shift;
    my $ride_id = shift;
    my $ride_path = setting ( 'raw_log_dir' ) . '/' . $user_id . '/' . $ride_id;
    debug ( 'user_id: ' . $user_id );
    debug ( 'ride_id: ' . $ride_id );
    debug ( 'ride_path: ' . $ride_path );
    my $fh;
    if ( ! open ( $fh, $ride_path . '/ride_info.json' ) ) {
        return undef;
    }
    local $/ = undef;
    my $ride_info_str = <$fh>;
    my $ride_info = eval { from_json ( $ride_info_str ) };
    if ( $@ ) {
        warning ( 'Failed to get data from file: ' . $ride_info_str . '. Error: ' . $@ );
        return undef;
    }
    return $ride_info;
}

sub updateRideInfo {
    my $user_id = shift;
    my $ride_id = shift;
    my $ride_info = shift;
    my $ride_path = setting ( 'raw_log_dir' ) . '/' . $user_id . '/' . $ride_id;
    my $ride_file = $ride_path . '/ride_info.json';
    my $tmp_file = $ride_file . '.tmp';
    debug ( 'user_id: ' . $user_id );
    debug ( 'ride_id: ' . $ride_id );
    debug ( 'ride_path: ' . $ride_path );
    my $output_meta_fh;
    if ( ! open ( $output_meta_fh, '>', $tmp_file ) ) {
        error ( "coudn't open tmp file: $!" );
        return undef;
    }
    print $output_meta_fh to_json ( $ride_info, { pretty => 1, canonical => 1 } );

    close ( $output_meta_fh );

    if ( ! rename ( $tmp_file, $ride_file ) ) {
        error ( "coudn't rename tmp file: '$tmp_file', $!" );
        return undef;
    }
    return 1;
}

1;
