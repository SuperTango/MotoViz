package MotoViz::RideInfo;
use strict;
use warnings;
use Dancer qw( :syntax );

sub getRideInfos {
    my $user_id = shift;
    my $user_path = setting ( 'raw_log_dir' ) . '/' . $user_id;
    my $dirFH;
    if ( ! opendir ( $dirFH, $user_path ) ) {
        return undef;
    }
    my $ride_infos = [];
    foreach my $ride_id ( sort ( readdir ( $dirFH ) ) ) {
        next if ( $ride_id !~ /^rid_/ );
        my $ride_info = getRideInfo ( $user_id, $ride_id );
        if ( $ride_info ) {
            $ride_info->{'ride_id'} = $ride_id;
            push ( @{$ride_infos}, $ride_info );
        }
    }
    return $ride_infos;
}

sub getRideInfo {
    my $user_id = shift;
    my $ride_id = shift;
    my $ride_path = setting ( 'raw_log_dir' ) . '/' . $user_id . '/' . $ride_id;
    debug ( 'user_id: ' . $user_id );
    debug ( 'ride_id: ' . $ride_id );
    debug ( 'ride_path: ' . $ride_path );
    my $fh;
    if ( ! open ( $fh, $ride_path . '/motoviz_output.out.meta' ) ) {
        return undef;
    }
    local $/ = undef;
    my $ride_info_str = <$fh>;
    my $ride_info = from_json ( $ride_info_str );
    return $ride_info;
}

sub updateRideInfo {
    my $user_id = shift;
    my $ride_id = shift;
    my $ride_data = shift;
    my $ride_path = setting ( 'raw_log_dir' ) . '/' . $user_id . '/' . $ride_id;
    my $ride_file = $ride_path . '/motoviz_output.out.meta';
    my $tmp_file = $ride_file . '.tmp';
    debug ( 'user_id: ' . $user_id );
    debug ( 'ride_id: ' . $ride_id );
    debug ( 'ride_path: ' . $ride_path );
    my $output_meta_fh;
    if ( ! open ( $output_meta_fh, '>', $tmp_file ) ) {
        error ( "coudn't open tmp file: $!" );
        return undef;
    }
    print $output_meta_fh to_json ( $ride_data, { pretty => 1, canonical => 1 } );

    close ( $output_meta_fh );

    if ( ! rename ( $tmp_file, $ride_file ) ) {
        error ( "coudn't rename tmp file: '$tmp_file', $!" );
        return undef;
    }
    return 1;
}

1;
