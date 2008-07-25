package Twirc::Jabber;
use utf8;
use Moose;

use POE;
use POE::Component::Jabber;
use POE::Component::Jabber::Error;
use POE::Component::Jabber::Status;
use POE::Component::Jabber::ProtocolFactory;
use POE::Filter::XML::Node;
use POE::Filter::XML::NS qw/:JABBER :IQ/;
use POE::Filter::XML::Utils;

has username => (
    is  => 'rw',
    isa => 'Str',
);

has password => (
    is  => 'rw',
    isa => 'Str',
);

has server => (
    is  => 'rw',
    isa => 'Str',
);

has port => (
    is  => 'rw',
    isa => 'Int',
);

has component => (
    is => 'rw',
);

sub spawn {
    my $self = shift;

    POE::Session->create(
        object_states => [
            $self => [qw/_start status_handler input_handler error_handler send_message/],
        ],
    );
}

sub debug(@) {
    print @_ if $ENV{TWITDEBUG};
}

sub _start {
    my ($self, $kernel) = @_[OBJECT, KERNEL];

    $kernel->alias_set('im');

    my ($username, $hostname) = split '@', $self->username;

    my $jabber = POE::Component::Jabber->new(
        IP       => $self->server,
        Port     => $self->port || 5222,
        Hostname => $hostname,
        Username => $username,
        Password => $self->password,
        Alias    => 'jabber',
        States   => {
            StatusEvent => 'status_handler',
            InputEvent  => 'input_handler',
            ErrorEvent  => 'error_handler',
        },
        ConnectionType => +XMPP,
#        Debug          => 1,
    );
    $self->{component} = $jabber;

    $kernel->post( jabber => 'connect' );
}

sub status_handler {
    my ($self, $kernel, $sender, $state) = @_[OBJECT, KERNEL, SENDER, ARG0];

    if ($state == +PCJ_INIT_FINISHED) {
        my $jid = $self->component->jid;

        $self->{jid} = $jid;
        $self->{sid} = $sender->ID;

        $kernel->post(jabber => 'output_handler', POE::Filter::XML::Node->new('presence'));
        $kernel->post(jabber => 'purge_queue');
    }
}

sub input_handler {
    my ($self, $kernel, $node) = @_[OBJECT, KERNEL, ARG0];

    debug "recv:", $node->to_str, "\n\n";

    my ($body) = $node->get_tag('body');
    if ($body) {
        $kernel->post( ircd => 'publish_message', {
            from    => $node->attr('from'),
            message => $body->data,
        });
    }
}

sub send_message {
    my ($self, $kernel, $msg) = @_[OBJECT, KERNEL, ARG0];

    my $node = POE::Filter::XML::Node->new('message');

    $node->attr('to', $msg->{to});
    $node->attr('from', $self->component->jid );
    $node->attr('type', 'chat');
    $node->insert_tag('body')->data( $msg->{message} );

    debug "send:", $node->to_str, "\n\n";

    $kernel->post( $self->{sid} => output_handler => $node )
}

sub error_handler {
    my ($kernel, $sender, $error) = @_[KERNEL, SENDER, ARG0];

    if ( $error == +PCJ_SOCKETFAIL or $error == +PCJ_SOCKETDISCONNECT or $error == +PCJ_CONNECTFAIL ) {
        print "Reconnecting!\n";
        $kernel->post( $sender, 'reconnect' );
    }
    elsif ( $error == +PCJ_SSLFAIL ) {
        print "TLS/SSL negotiation failed\n";
    }
    elsif ( $error == +PCJ_AUTHFAIL ) {
        print "Failed to authenticate\n";
    }
    elsif ( $error == +PCJ_BINDFAIL ) {
        print "Failed to bind a resource\n";
    }
    elsif ( $error == +PCJ_SESSIONFAIL ) {
        print "Failed to establish a session\n";
    }
}

1;
