package Twirc::Jabber;
use strict;
use warnings;

use POE;
use POE::Component::Jabber;
use POE::Component::Jabber::Error;
use POE::Component::Jabber::Status;
use POE::Component::Jabber::ProtocolFactory;
use POE::Filter::XML::Node;
use POE::Filter::XML::NS qw/:JABBER :IQ/;
use POE::Filter::XML::Utils;

sub spawn {
    my $class = shift;
    my $config = @_ > 1 ? {@_} : $_[0];

    POE::Session->create(
        package_states => [
            __PACKAGE__, [qw/_start status_handler input_handler error_handler send_message/],
        ],
        heap => { config => $config },
    );
}

sub debug(@) {
    print @_ if $ENV{TWITDEBUG};
}

sub _start {
    my ($kernel, $heap) = @_[KERNEL, HEAP];

    $kernel->alias_set('im');

    my $config = $heap->{config};
    my ($username, $hostname) = split '@', $config->{username};

    my $jabber = POE::Component::Jabber->new(
        IP       => $config->{server},
        Port     => $config->{port} || 5222,
        Hostname => $hostname,
        Username => $username,
        Password => $config->{password},
        Alias    => 'jabber',
        States   => {
            StatusEvent => 'status_handler',
            InputEvent  => 'input_handler',
            ErrorEvent  => 'error_handler',
        },
        ConnectionType => +XMPP,
#        Debug          => 1,
    );
    $heap->{jabber} = $jabber;

    $kernel->post( jabber => 'connect' );
}

sub status_handler {
    my ($kernel, $sender, $heap, $state) = @_[KERNEL, SENDER, HEAP, ARG0];

    if ($state == +PCJ_INIT_FINISHED) {
        my $jid = $heap->{jabber}->jid;

        $heap->{jid} = $jid;
        $heap->{sid} = $sender->ID;

        $kernel->post(jabber => 'output_handler', POE::Filter::XML::Node->new('presence'));
        $kernel->post(jabber => 'purge_queue');
    }
}

sub input_handler {
    my ($kernel, $heap, $node) = @_[KERNEL, HEAP, ARG0];

    debug "recv:", $node->to_str, "\n\n";

    my ($body) = $node->get_tag('body');
    if ($body && $node->attr('from') =~ /^twitter\@twitter\.com/) {
        $kernel->post( ircd => 'publish_message', $body->data );
    }
}

sub send_message {
    my ($kernel, $heap, $message) = @_[KERNEL, HEAP, ARG0];

    my $node = POE::Filter::XML::Node->new('message');

    $node->attr('to', 'twitter@twitter.com');
    $node->attr('from', $heap->{jid} );
    $node->attr('type', 'chat');
    $node->insert_tag('body')->data( $message );

    debug "send:", $node->to_str, "\n\n";

    $kernel->post( $heap->{sid} => output_handler => $node )
}

sub error_handler { }

1;
