package MotoViz::RESTHelper;

use strict;
use warnings;

use JSON;

sub readFromFile {
    my $file = shift;
    my $fh;
    local $/ = undef;
    if ( ! open ( $fh, $file ) ) {
        return { code => -1, message => "failed to open file: $file: $!" };
    }
    my $text = <$fh>;
    close ( $fh );
    my $data;
    eval {
        $data = decode_json ( $text );
    return { code => 1, data => $data };
        1;
    } or do {
        return { code => -1, message => 'JSON parsing failed. ' . $@ };
    };

}

sub writeToFile {
    my $file = shift;
    my $data = shift;
    my $tmpFile = $file . '.tmp';
    my $fh;
    if ( ! open ( $fh, '>', $tmpFile ) ) {
        return { code => -1, message => "failed to open file $file for writing. Error: $!" };
    }
    if ( ! print $fh JSON->new->utf8->pretty->encode ( $data ) ) {
        return { code => -1, message => "failed when trying to write to json file: '$file'. Error: $!" };
    }
    if ( ! close ( $fh ) ) {
        return { code => -1, message => "failed when trying to close json file: '$file'. Error: $!" };
    }
    if ( ! rename ( $tmpFile, $file ) ) {
        return { code => -1, message => "failed when trying to rename json file: '$file'. Error: $!" };
    }
    return { code => 1, message => 'success' };
}


1;

