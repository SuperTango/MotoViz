package RESTRoutes;
use Dancer ':syntax';
use Dancer::Plugin::DBIC;
use Data::Dump qw( pp );
use Data::UUID;
use File::Path;
use MotoViz::CAFileProcessor;

our $VERSION = '0.1';

sub return_json {
    my $data = shift;
    my $options = shift;
    debug ( pp ( params ) );
    if ( exists params->{'pretty'} ) {
        if ( ! $options ) {
            $options = {};
        }
        $options->{'pretty'} = 1;
    } 
    debug ( 'options: ' .  pp ( $options ) );

    return to_json ( $data, $options );
}

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
    return return_json ( $ret );
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
    return return_json ( \%cols );
};

get '/v1/rides/:user_id' => sub {
    my $ride_infos = schema->resultset('Ride')->search({ user_id => params->{'user_id'} });
    my $array = [];
    while ( my $ride_info = $ride_infos->next ) {
        debug ( "got ride: " . $ride_info->ride_id );
        debug ( "request base: " . request->base );
        debug ( "request base: " . ref ( request->base ) );
        my %cols = $ride_info->get_columns;
        debug ( "cols: " . pp ( \%cols ) );
        $cols{'ride_url'} = 'http://motoviz.funkware.com/v1/rides/' . params->{'user_id'} . '/' . $ride_info->ride_id;
        $cols{'points_url'} = 'http://motoviz.funkware.com/v1/points/' . params->{'user_id'} . '/' . $ride_info->ride_id;

        push ( @{$array}, \%cols );
    }
    if ( ! @{$array} ) {
        status 'not_found';
        return;
    } else {
        content_type 'application/json';
        return return_json ( $array );
    }
};

sub fetch_points {
    my $ride_info = shift;
    my $limit_points = shift;
    
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
            my $raw_point = from_json ( $line );
            push ( @{$points}, $raw_point );
        }
        $count++;
    }
    return $points;
}

true;
