use strict;
use warnings;
use Dancer ':syntax';
use Plack::Builder;

# this is an attempt to run two apps in the same server like starman.  
# unfortunately, it doesn't work very well, so isn't really worth it.
#
# The answer has been to run two different starman servers or run 
# two cgis.
setting apphandler => 'PSGI';

my $app1 = sub {
    my $env = shift;
    local $ENV{DANCER_APPDIR} = '/funk/home/altitude/MotoViz/MotoViz';
    setting appdir => '/funk/home/altitude/MotoViz/MotoViz';
    setting log_path => '/funk/home/altitude/MotoViz/MotoViz/logs';
    load_app "UIRoutes";
    Dancer::App->set_running_app('UIRoutes');
    Dancer::Config->load;
    my $request = Dancer::Request->new( env => $env );
    Dancer->dance($request);
};

my $app2 = sub {
    my $env = shift;
    local $ENV{DANCER_APPDIR} = '/funk/home/altitude/MotoViz/MotoViz_API';
    setting appdir => '/funk/home/altitude/MotoViz/MotoViz_API';
    setting log_path => '/funk/home/altitude/MotoViz/MotoViz_API/logs';
    load_app "RESTRoutes";
    Dancer::App->set_running_app('RESTRoutes');
    Dancer::Config->load;
    my $request = Dancer::Request->new( env => $env );
    Dancer->dance($request);
};

builder {
    mount "/" => builder {$app1};
    mount "/api" => builder {$app2};
};
