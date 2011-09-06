#!/usr/bin/env perl
use Dancer;
use RESTRoutes;
#Dancer::App->set_running_app ( 'API_MotoViz' );
$ENV{'TMPDIR'} = '/funk/home/altitude/MotoViz/MotoViz_API/var/tmp';
dance;
