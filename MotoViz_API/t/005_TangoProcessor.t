use Test::More qw( no_plan );
use strict;
use warnings;

# the order is important
use MotoViz::TangoLoggerProcessor;
use Dancer::Test;
use Dancer qw( setting );
use Data::Dump qw( pp );
use Cwd;

my $tangoProcessor = new MotoViz::TangoLoggerProcessor();
isa_ok ( $tangoProcessor, 'MotoViz::TangoLoggerProcessor' );
my $testDir = 't/data/TangoLoggerProcessor';
my $testFile1 = $testDir . '/2011_08_29-12_14_54-log.CSV';

my $ret;
$ret = $tangoProcessor->init ( 'test_ride_id', $testFile1 );
ok ( $ret->{'code'} == 1, "init good files" ) || diag ( pp ( $ret ) );

$ret = $tangoProcessor->getNextRecord();
#print pp ( $tangoProcessor );
$ret = $tangoProcessor->getNextRecord();
$ret = $tangoProcessor->getNextRecord();
$ret = $tangoProcessor->getNextRecord();
$ret = $tangoProcessor->getNextRecord();
$ret = $tangoProcessor->getNextRecord();
$ret = $tangoProcessor->getNextRecord();

# for ( 1..100 ) {
# $ret = $caFileProcessor->getNextRecord();
# #diag ( pp ( $ret ) );
# }
# ok ( $ret->{'code'} == 1, "getNextRecord" ) || diag ( pp ( $ret ) );
