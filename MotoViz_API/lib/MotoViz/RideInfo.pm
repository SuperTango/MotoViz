package MotoViz::RideInfo;
use strict;
use warnings;
use Dancer qw( :syntax );

sub getRideInfos {
    my $user_id = shift;
    my $user_path = setting ( 'raw_log_dir' ) . '/' . $user_id;
    my $dirFH;
    if ( ! opendir ( $dirFH, $user_path ) ) {
        return { code => -404, message => 'user not found' };
    }
    my $ride_infos = [];
    foreach my $ride_id ( sort ( readdir ( $dirFH ) ) ) {
        next if ( $ride_id !~ /^rid_/ );
        my $ride_info = getRideInfo ( $user_id, $ride_id );
        $ride_info->{'ride_id'} = $ride_id;
        push ( @{$ride_infos}, $ride_info );
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

1;
