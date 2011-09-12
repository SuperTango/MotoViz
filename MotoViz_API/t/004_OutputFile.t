use Test::More qw( no_plan );
use strict;
use warnings;

# the order is important
use MotoViz::OutputProcessor;
use MotoViz::CAFileProcessor;
use Dancer::Test;
use Dancer qw( setting );
use Data::Dump qw( pp );
use Cwd;

my $outputFileProcessor = new MotoViz::OutputProcessor();
isa_ok ( $outputFileProcessor, 'MotoViz::OutputProcessor' );

my $testDir = 't/data/CAFileProcessor';

my $caFileProcessor = new MotoViz::CAFileProcessor();
my $ret = $caFileProcessor->init ( 'test_ride1', $testDir . '/GoodFile', $testDir . '/GoodNMEAFile' );
ok ( $ret->{'code'} == 1, "init good files" ) || diag ( pp ( $ret ) );

$ret = $outputFileProcessor->init ( 'test_user1', 'test_ride1', 'test title 1', 0, $caFileProcessor );
diag ( pp ( $ret ) );
ok ( $ret->{'code'} == 1 ) || diag ( pp ( $ret ) );

$ret = $outputFileProcessor->generateOutputFile();
diag ( pp ( $ret ) );
ok ( $ret->{'code'} == 1 ) || diag ( pp ( $ret ) );

# my $caFileProcessor = new MotoViz::CAFileProcessor();
# isa_ok ( $caFileProcessor, 'MotoViz::CAFileProcessor' );
# 
# my $ret = $caFileProcessor->verifyCALogFile();
# ok ( $ret->{'code'} == 1 && $ret->{'data'} == 0, "verifyCALogFile on non-existant file" );
# 
# $ret = $caFileProcessor->verifyCALogFile ( $testFile1 );
# ok ( $ret->{'code'} == 1 && $ret->{'data'} == 0, "verifyCALogFile on bad file" );
# 
# $ret = $caFileProcessor->verifyCALogFile ( $testDir . '/AlmostGoodCALogFile.txt' );
# ok ( $ret->{'code'} == 1 && $ret->{'data'} == 0, "verifyCALogFile on almost good file" );
# 
# $ret = $caFileProcessor->verifyCALogFile ( $testDir . '/GoodFile' );
# ok ( $ret->{'code'} == 1 && $ret->{'data'} == 1, "verifyCALogFile on good file" );
# 
# $ret = $caFileProcessor->verifyNMEAFile();
# ok ( $ret->{'code'} == 1 && $ret->{'data'} == 0, "verifyNMEAFile on non-existant file" );
# 
# $ret = $caFileProcessor->verifyNMEAFile ( $testFile1 );
# ok ( $ret->{'code'} == 1 && $ret->{'data'} == 0, "verifyNMEAFile on bad file" );
# 
# $ret = $caFileProcessor->verifyNMEAFile ( $testDir . '/AlmostGoodNMEAFile.txt' );
# ok ( $ret->{'code'} == 1 && $ret->{'data'} == 0, "verifyNMEAFile on almost good file" );
# 
# $ret = $caFileProcessor->verifyNMEAFile ( $testDir . '/GoodNMEAFile' );
# ok ( $ret->{'code'} == 1 && $ret->{'data'} == 1, "verifyNMEAFile on good file" ) || diag ( pp ( $ret ) );
# 
# $ret = $caFileProcessor->init ( 'test_ride_id', $testDir . '/GoodFile', $testDir . '/GoodNMEAFile' );
# ok ( $ret->{'code'} == 1, "init good files" ) || diag ( pp ( $ret ) );
# 
# for ( 1..100 ) {
# $ret = $caFileProcessor->getNextRecord();
# #diag ( pp ( $ret ) );
# }
# ok ( $ret->{'code'} == 1, "getNextRecord" ) || diag ( pp ( $ret ) );
