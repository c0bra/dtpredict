use inc::Module::Install;

name     'DateTime-Event-Predict';
all_from 'lib/DateTime/Event/Predict.pm';
author   'Brian Hann <brian.hann+dtp@gmail.com>';
license  'perl';
no_index directory => 'research';

perl_version_from 'lib/DateTime/Event/Predict.pm';

build_requires 'Test::More';
requires       'DateTime'  => 0;
requires	   'Params::Validate' => '0.91';
requires       'Scalar::Util';

auto_install;

WriteAll;

