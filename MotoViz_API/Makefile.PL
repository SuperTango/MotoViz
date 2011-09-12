use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'MotoViz',
    AUTHOR              => q{Alex Tang <altitude@funkwar.com>},
    VERSION_FROM        => 'lib/RESTRoutes.pm',
    ABSTRACT            => 'MotoViz REST api',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'YAML'       => 0,
        'Dancer'     => 1.3072,
        'Data::Dump' => 0,
        'GPS::Point' => 0,
        'Geo::Inverse' => 0,
        'Data::UUID' => 0,

    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'MotoViz-*' },
);
