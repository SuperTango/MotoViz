package MotoViz::NMEAParser;
use strict;
use warnings;
use Dancer qw( :syntax );
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
    $self->{'date_last'} = { mon => 0, day => 1, year => 2000 };

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
            $self->parse_gprmc ( $gprmc_record, $gps_line );
            #print pp ( $gprmc_record ) . "\n";
            if ( defined $self->{'last_gprmc_record'} ) {
                #print "Already read a gprmc, returning old gprmc, setting last_gprmc to current gprmc\n";
                $final_record = $self->{'last_gprmc_record'};
                $self->{'last_gprmc_record'} = $gprmc_record;
                last;
            } elsif ( defined $self->{'last_gpgga_record'} ) {
                if ( $self->{'last_gpgga_record'}->{'time'} != $gprmc_record->{'time'} ) {
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
            $self->parse_gpgga ( $gpgga_record, $gps_line );
            #print pp ( $gpgga_record ) . "\n";
            if ( defined $self->{'last_gpgga_record'} ) {
                #print "Already read a gpgaa, returning old gpgga, setting last_gpgga to current gpgga\n";
                $final_record = $self->{'last_gpgga_record'};
                $self->{'last_gpgga_record'} = $gpgga_record;
                last;
            } elsif ( defined $self->{'last_gprmc_record'} ) {
                if ( $self->{'last_gprmc_record'}->{'time'} != $gpgga_record->{'time'} ) {
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
    my $self = shift;
    my $record = shift;
    my $gps_line = shift;
    my ( $type, $sat_time, $sat_fix, $gps_lat, $lat_hem, $gps_lon, $lon_hem, $speed_gps, $bearing, $sat_date, $checksum ) = split ( /,/, $gps_line );
    return 0 if ( $type ne '$GPRMC' );
    return 0 if ( ! validate_checksum ( $gps_line ) );
    $record->{'gprmc_line'} = $gps_line;
    my ( $hour, $min, $sec, $millis ) = $sat_time =~ /(\d\d)(\d\d)(\d\d)\.(\d\d\d)/;
    my ( $day, $mon, $year ) = $sat_date =~ /(\d\d)(\d\d)(\d\d)/;
    $year += 2000;
    if ( $mon > 0 ) { 
        $mon--;
    }
    $self->{'date_last'} = { year =>  $year, mon => $mon, day => $day };
    $record->{'time'} = timegm($sec,$min,$hour,$day, $mon ,$year) . '.' . $millis;
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
    $record->{'speed_gps'} = $speed_gps *= 1.15077945;
    $record->{'bearing'} = $bearing;
    return 1;
}

sub parse_gpgga {
    my $self = shift;
    my $record = shift;
    my $gps_line = shift;
    my ( $type, $sat_time, $gps_lat, $lat_hem, $gps_lon, $lon_hem, $fix_quality, $num_sats, $hdop, $altitude, $altitude_units, $geoidl_separation, $geoidl_separation_units, $age, $diff, $checksum   ) = split ( /,/, $gps_line );
    return 0 if ( $type ne '$GPGGA' );
    return 0 if ( ! validate_checksum ( $gps_line ) );
    #return 0 if ( $sat_fix ne 'A' );
    $record->{'gpgga_line'} = $gps_line;
    my ( $hour, $min, $sec, $millis ) = $sat_time =~ /(\d\d)(\d\d)(\d\d)\.(\d\d\d)/;
    $record->{'time'} = timegm($sec,$min,$hour,$self->{'date_last'}->{'day'}, $self->{'date_last'}->{'mon'}, $self->{'date_last'}->{'year'} ) . '.' . $millis;
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


1;
