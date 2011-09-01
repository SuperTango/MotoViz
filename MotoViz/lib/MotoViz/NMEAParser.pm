package MotoViz::NMEAParser;
use strict;
use warnings;
use Data::Dump qw( pp );
use GPS::Point;
use Time::Local;


sub new {
    my $class = shift;
    my $self = {};
    $self->{'ready'} = 0;
    bless $self, $class;
    return $self;
}

sub init {
    my $self = shift;
    $self->{'nmea_file'} = shift;
    $self->{'last_gprmc_record'} = undef;
    $self->{'last_gpgga_record'} = undef;

    if ( ! -f $self->{'nmea_file'} ) {
        my $msg = 'NMEA file specified: "' . $self->{'nmea_file'} . '" does not exist';
        debug ( $msg );
        return { code => -1, message => $msg };
    }
    if ( open ( $self->{'fh'}, $self->{'nmea_file'} ) ) {
        $self->{'ready'} = 1;
        return { code => 1, message => 'success' };

    } else {
        my $msg = 'Failed to open NMEA file: "' . $self->{'nmea_file'} . '". Error: ' . $!;
        $self->{'ready'} = 0;
        debug ( $msg );
        return { code => -1, message => $msg };
    }
}

sub get_next_record {
    my $self = shift;
    my $input_record = shift;
    if ( ! $self->{'ready'} ) {
        return { code => -1, message => 'not ready' };
    }
    if ( ! defined $input_record ) {
        $input_record = {};
    }
    my $gprmc_record = {};
    my $gpgga_record = {};
    my $fh = $self->{'fh'};
    my $final_record;
    while ( my $gps_line = <$fh> ) {
        next if ( $gps_line !~ /^\$(GPRMC|GPGGA)/ );
        #print $gps_line;
        if ( $1 eq 'GPRMC' ) {
            parse_gprmc ( $gprmc_record, $gps_line );
            #print pp ( $gprmc_record ) . "\n";
            if ( defined $self->{'last_gprmc_record'} ) {
                #print "Already read a gprmc, returning old gprmc, setting last_gprmc to current gprmc\n";
                $final_record = $self->{'last_gprmc_record'};
                $self->{'last_gprmc_record'} = $gprmc_record;
                last;
            } elsif ( defined $self->{'last_gpgga_record'} ) {
                if ( $self->{'last_gpgga_record'}->{'time'} ne $gprmc_record->{'time'} ) {
                    #print "Already read a have a gpgga, but times don't match.  Returning last gpgga, setting last gprmc to current gprmc\n";
                    $final_record = $self->{'last_gpgga_record'};
                    $self->{'last_gpgga_record'} = undef;
                    $self->{'last_gprmc_record'} = $gprmc_record;
                    last;

                } else {
                    #print "Already read a have a gpgga, times match.  combining\n";
                    my %tmp = ( %{$self->{'last_gpgga_record'}}, %{$gprmc_record} );
                    $self->{'last_gpgga_record'} = undef;
                    $self->{'last_gprmc_record'} = undef;
                    $final_record = \%tmp;
                    last;
                }
            } else {
                $self->{'last_gprmc_record'} = $gprmc_record;
            }
        } elsif ( $1 eq 'GPGGA' ) {
            parse_gpgga ( $gpgga_record, $gps_line );
            #print pp ( $gpgga_record ) . "\n";
            if ( defined $self->{'last_gpgga_record'} ) {
                #print "Already read a gpgaa, returning old gpgga, setting last_gpgga to current gpgga\n";
                $final_record = $self->{'last_gpgga_record'};
                $self->{'last_gpgga_record'} = $gpgga_record;
                last;
            } elsif ( defined $self->{'last_gprmc_record'} ) {
                if ( $self->{'last_gprmc_record'}->{'time'} ne $gpgga_record->{'time'} ) {
                    #print "Already read a have a gprmc, but times don't match.  REturning last gprmc, setting last gpgga to current gpgga\n";
                    $final_record = $self->{'last_gprmc_record'};
                    $self->{'last_gprmc_record'} = undef;
                    $self->{'last_gpgga_record'} = $gpgga_record;
                    last;

                } else {
                    #print "Already read a have a gprmc, times match.  combining\n";
                    my %tmp = ( %{$self->{'last_gprmc_record'}}, %{$gpgga_record} );
                    $self->{'last_gprmc_record'} = undef;
                    $self->{'last_gpgga_record'} = undef;
                    $final_record = \%tmp;
                    last;
                }
            } else {
                $self->{'last_gpgga_record'} = $gpgga_record;
            }
        }
    }
    while ( my ( $key, $value) = each %{$final_record} ) {
        $input_record->{$key} = $value;
    }
    return $input_record;

}

sub parse_gprmc {
    my $record = shift;
    my $gps_line = shift;
    my ( $type, $sat_time, $sat_fix, $gps_lat, $lat_hem, $gps_lon, $lon_hem, $gps_speed, $bearing, $sat_date, $checksum ) = split ( /,/, $gps_line );
    return 0 if ( $type ne '$GPRMC' );
    return 0 if ( ! validate_checksum ( $gps_line ) );
    $record->{'gprmc_line'} = $gps_line;
    my ( $hour, $min, $sec, $millis ) = $sat_time =~ /(\d\d)(\d\d)(\d\d)\.(\d\d\d)/;
    my ( $day, $mon, $year ) = $sat_date =~ /(\d\d)(\d\d)(\d\d)/;
    $year += 2000;
    $record->{'date'} = sprintf ( "%04d-%02d-%02d", $year, $mon, $day );
    $record->{'time'} = sprintf ( "%02d:%02d:%02d", $hour, $min, $sec );
    $record->{'timestamp'} = timegm($sec,$min,$hour,$day,( $mon - 1 ) ,$year) . '.' . $millis;
    return 0 if ( $sat_fix ne 'A' );
    if ( ! $lat_hem ) {
        return 1;
    }

    my ( $lat_deg, $lat_min ) = $gps_lat =~ /(\d\d)(\d\d\.\d+)/;
    my ( $lon_deg, $lon_min ) = $gps_lon =~ /(\d\d)(\d\d\.\d+)/;
    $lat_deg += ( $lat_min / 60 );
    $lat_deg = -$lat_deg if ( $lat_hem eq 'S' );
    $record->{'lat'} = $lat_deg;

    $lon_deg += ( $lon_min / 60 );
    $lon_deg = -$lon_deg if ( $lon_hem eq 'W' );
    $record->{'lon'} = $lon_deg;
    $record->{'gps_speed'} = $gps_speed *= 1.15077945;
    $record->{'bearing'} = $bearing;
    return 1;
}

sub parse_gpgga {
    my $record = shift;
    my $gps_line = shift;
    my ( $type, $sat_time, $gps_lat, $lat_hem, $gps_lon, $lon_hem, $fix_quality, $num_sats, $hdop, $altitude, $altitude_units, $geoidl_separation, $geoidl_separation_units, $age, $diff, $checksum   ) = split ( /,/, $gps_line );
    return 0 if ( $type ne '$GPGGA' );
    return 0 if ( ! validate_checksum ( $gps_line ) );
    #return 0 if ( $sat_fix ne 'A' );
    $record->{'gpgga_line'} = $gps_line;
    my ( $hour, $min, $sec, $millis ) = $sat_time =~ /(\d\d)(\d\d)(\d\d)\.(\d\d\d)/;
    $record->{'time'} = sprintf ( "%02d:%02d:%02d", $hour, $min, $sec );
    $record->{'altitude'} = $altitude;
    $record->{'altitude_units'} = $altitude_units;
    $record->{'num_sats'} = $num_sats;
    if ( ! $lat_hem ) {
        return 1;
    }
    my ( $lat_deg, $lat_min ) = $gps_lat =~ /(\d\d)(\d\d\.\d+)/;
    my ( $lon_deg, $lon_min ) = $gps_lon =~ /(\d\d)(\d\d\.\d+)/;
    $lat_deg += ( $lat_min / 60 );
    $lat_deg = -$lat_deg if ( $lat_hem eq 'S' );
    $record->{'lat'} = $lat_deg;

    $lon_deg += ( $lon_min / 60 );
    $lon_deg = -$lon_deg if ( $lon_hem eq 'W' );
    $record->{'lon'} = $lon_deg;
    return 1;
}

sub validate_checksum {
    my $line = shift;
    my ( $data, $checksum ) = $line =~ /^\s*\$(.*?)\*(.*?)\s*$/;
    if ( ! $data ) {
        return 0;
    }
    my $calculated_checksum = calculate_checksum ( $data );
    #print "Data:        '$data'\n";
    #print "line:        '$checksum'\n";
    #print "calculated:  '$calculated_checksum'\n";
    #exit;
    if ( $checksum ne $calculated_checksum ) {
        return 0;
    } else {
        return 1;
    }
}

sub calculate_checksum {
    my ($line) = @_;
    $line =~ s/\*.*//;
    my $csum = 0;
    $csum ^= unpack("C",(substr($line,$_,1))) for(0..length($line)-1);

    #printf ( "Checksum: %2.2X, $csum\n", $csum );
    return (sprintf("%2.2X",$csum));
}

sub fetch_points {
    my $user = shift;
    my $uuid = shift;
    my $max_points = shift;
    my $requested_metrics = shift;
    my $json = JSON->new->allow_nonref;
    
    my $baseDir = '/funk/home/altitude/public_html/markcycle/data/' . $user;
    my $dir = $baseDir . '/' . $uuid;
    my $src_file = $dir . '/output_file';
    my $meta_file = $dir . '/output_meta_file';
    my $meta_data;
    {
        my $fh;
        local $/ = undef;
        open ( $fh, $meta_file ) || die;
        my $str = <$fh>;
        close ( $fh );
        $meta_data = $json->decode ( $str );
    }
        #
        # $mod is the ( total number of points / ( max_points - 1 ) ).
        # to figure out which points from the original set to put in the final set,
        # keep track of the last int ( $point_num / $mod ).  If the int value 
        # is different than the last one, include the point.  Otherwise,
        # discard the point.
        #
    my $mod = $meta_data->{'record_count'} / ( $max_points );
    my $lastInt = -1;
    my $count = 0;
    my $fh;
    open ( $fh, $src_file ) || die;
    my $new_records = [];
    my $new_records2 = {};
    while ( my $line = <$fh> ) {
        my $tmp = int ( $count / $mod );
        if ( $tmp != $lastInt ) {
            $lastInt = $tmp;
            my $record = $json->decode ( $line );
            my $new_record = {};
            foreach my $metric ( @{$requested_metrics}, 'date', 'time', 'timestamp' ) {
                push ( @{$new_records2->{$metric}}, ( exists $record->{$metric} ? $record->{$metric} += 0 : undef ) );
                #$new_record->{$metric} = $record->{$metric};
            }
            #$new_record->{'date'} = $record->{'date'};
            #$new_record->{'time'} = $record->{'time'};
            #$new_record->{'timestamp'} = $record->{'timestamp'};
            #print $json->encode ( $new_record ) . "\n";
            #push ( @{$new_records}, $new_record );
        }
        $count++;
    }
    return $new_records2;
}

1;
