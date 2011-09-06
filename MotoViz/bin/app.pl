#!/usr/bin/env perl
use Dancer;
use UIRoutes;
#Dancer::App->set_running_app ( 'UI_MotoViz' );
$ENV{'TMPDIR'} = '/funk/home/altitude/MotoViz/MotoViz/var/tmp';
dance;
