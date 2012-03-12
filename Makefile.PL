use inc::Module::Install;

name     'DateTime-Event-Predict';
all_from 'lib/DateTime/Event/Predict.pm';
author   'Brian Hann <brian.hann@gmail.com>';
license  'perl';

no_index directory => 'research';
no_index file      => 'IDEAS';

test_requires 'Test::More' => '0.94';
requires       'DateTime'  => 0;
requires	   'Params::Validate' => '0.91';
requires       'Scalar::Util';
requires       'List::Util';

auto_install;

WriteAll;
