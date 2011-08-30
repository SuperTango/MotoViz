package MotoViz;
use Dancer ':syntax';

our $VERSION = '0.1';

get '/' => sub {
    template 'index';
};

get '/hello/:name' => sub {
    template 'hello' => { number => 42 };
};


true;
