package Twirc::Server;
use strict;
use warnings;

use Clone qw/clone/;
use Encode;

use POE qw/Component::Server::IRC/;

sub spawn {
    my $class = shift;
    my $config = @_ > 1 ? {@_} : $_[0];

    $config->{servername} ||= 'twirc.ircd';
    $config->{client_encoding} ||= 'utf-8';

    my $ircd = POE::Component::Server::IRC->spawn( config => clone($config) );
    POE::Session->create(
        package_states => [
            __PACKAGE__, [qw/_start ircd_daemon_public publish_message/],
        ],
        heap => { ircd => $ircd, config => $config },
    );
}

sub _start {
    my ($kernel, $heap) = @_[KERNEL, HEAP];

    $kernel->alias_set('ircd');

    my ($ircd, $config) = @$heap{qw/ircd config/};

    $ircd->yield('register');
    $ircd->add_auth( mask => '*@*' );
    $ircd->add_listener( port => $config->{port} || 6667 );

    $ircd->yield( add_spoofed_nick => { nick => $config->{server_nick} } );
    $ircd->yield( daemon_cmd_join => $config->{server_nick}, '#twitter' );

    $heap->{nicknames} = {};
}

sub debug(@) {
    print @_ if $ENV{TWITDEBUG};
}

sub ircd_daemon_public {
    my ($kernel, $heap, $user, $channel, $text) = @_[KERNEL, HEAP, ARG0, ARG1, ARG2];
    my $encoding = $heap->{config}{client_encoding};

    $kernel->post( im => send_message => decode( $encoding, $text ) );
}

sub publish_message {
    my ($kernel, $heap, $message) = @_[KERNEL, HEAP, ARG0];

    debug "publish to irc: $message \n\n";

    my ($ircd, $config) = @$heap{qw/ircd config/};
    $message = encode( $config->{client_encoding}, $message );

    my ($nick, $text) = split ': ', $message;

    if ($nick && !$heap->{nicknames}->{ $nick = "\@$nick" }) {
        $ircd->yield( add_spoofed_nick => { nick => $nick } );
        $ircd->yield( daemon_cmd_join => $nick, '#twitter' );
        $heap->{nicknames}->{$nick}++;
    }

    if ($nick && $text) {
        $ircd->yield( daemon_cmd_privmsg => $nick => '#twitter', $text );
    }
    else {
        $ircd->yield( daemon_cmd_privmsg => $config->{server_nick}, '#twitter', $message );
    }
}

1;
