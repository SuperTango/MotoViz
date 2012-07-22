use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'MotoViz',
    AUTHOR              => q{YOUR NAME <altitude@funkware.com>},
    VERSION_FROM        => 'lib/MotoViz/Version.pm',
    ABSTRACT            => 'YOUR APPLICATION ABSTRACT',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'YAML'       => 0,
        'Dancer'     => 0,
        'Data::UUID'     => 0,
        'Template'     => 0,
        'Captcha::reCAPTCHA' => 0,
        'Crypt::Eksblowfish::Bcrypt' => 0,
        'JSON' => 0,
        'JSON::XS' => 0,
        'Starman' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'MotoViz-*' },
);
