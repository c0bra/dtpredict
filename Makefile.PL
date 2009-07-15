use inc::Module::Install;

name     'DateTime-Event-Predict';
all_from 'lib/DateTime/Event/Predict.pm';
author   'Brian Hann <brian.hann+dtp@gmail.com>';
license  'perl';
no_index directory => 'research';

build_requires 'Test::More';

auto_install;

WriteAll;

