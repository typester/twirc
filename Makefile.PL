use inc::Module::Install;
name 'Twirc';
all_from 'lib/Twirc.pm';

requires(
    'POE' => 0,
    'POE::Component::Server::IRC' => 0,
    'POE::Component::Jabber' => 0,
);

build_requires 'Test::More';
use_test_base;
auto_include;
WriteAll;
