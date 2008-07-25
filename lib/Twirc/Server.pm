package Twirc::Server;
use utf8;
use Moose;

use Clone qw/clone/;
use Encode;

use POE;
use POE::Component::Server::IRC;

has port => (
    is      => 'rw',
    isa     => 'Int',
    default => sub { 6667 },
);

has servername => (
    is      => 'rw',
    isa     => 'Str',
    default => sub { 'twirc.ircd' },
);

has nicklen => (
    is      => 'rw',
    isa     => 'Int',
    default => sub { 9 },
);

has antiflood => (
    is      => 'rw',
    isa     => 'Int',
    default => sub { 0 },
);

has client_encoding => (
    is      => 'rw',
    isa     => 'Str',
    default => sub { 'utf-8' },
);

has server_nick => (
    is      => 'rw',
    isa     => 'Str',
    default => sub { 'Twirc' },
);

has nicks => (
    is      => 'rw',
    isa     => 'HashRef',
    lazy    => 1,
    default => sub { {} },
);

has no_nick_tweaks => (
    is      => 'rw',
    isa     => 'Int',
    default => sub { 0 },
);

has channels => (
    is      => 'rw',
    isa     => 'ArrayRef',
    lazy    => 1,
    default => sub { [] },
);

has channel_nicks => (
    is      => 'rw',
    isa     => 'HashRef',
    lazy    => 1,
    default => sub { {} },
);

has component => (
    is => 'rw',
);

__PACKAGE__->meta->make_immutable;

sub spawn {
    my $self = shift;

    my $ircd = $self->{component} = POE::Component::Server::IRC->spawn(
        antiflood => $self->antiflood,
        config    => {
            servername => $self->servername,
        },
    );

    POE::Session->create(
        object_states => [
            $self => [qw/_start ircd_daemon_public publish_message/],
        ],
    );
}

sub _start {
    my ($self, $kernel) = @_[OBJECT, KERNEL];

    $kernel->alias_set( 'ircd' );

    my $ircd = $self->component;
    $ircd->yield('register');
    $ircd->add_auth( mask => '*@*' );
    $ircd->add_listener( port => $self->port );

    $ircd->yield( add_spoofed_nick => { nick => $self->server_nick } );

    $ircd->yield( daemon_cmd_join => $self->server_nick, $_ )
        for map { $_->{name} } @{ $self->channels };
}

sub debug(@) {
    print @_ if $ENV{TWITDEBUG};
}

sub ircd_daemon_public {
    my ($self, $kernel, $user, $channel, $text) = @_[OBJECT, KERNEL, ARG0..ARG2];

    my ($channel_info) = grep { $_->{name} eq $channel } @{ $self->channels }
        or return;

    $kernel->post( im => send_message => {
        to      => $channel_info->{target},
        message => decode( $self->client_encoding, $text ),
    });
}

sub publish_message {
    my ($self, $kernel, $heap, $msg) = @_[OBJECT, KERNEL, HEAP, ARG0];

    my ($channel) = map { $_->{name} } grep { $_->{target} =~ /^$msg->{from}/ } @{ $self->channels }
        or return;

    debug "publish to irc: <$msg->{from}> $msg->{message} \n\n";

    my $ircd = $self->component;

    my ($nick, $text) = $msg->{message} =~ /^(\w+): (.*)/;
    $nick = "\@$nick" if ($nick and !$self->no_nick_tweaks);

    if ($nick) {
        if (!$self->nicks->{ $nick }++) {
            $ircd->yield( add_spoofed_nick => { nick => $nick } );
        }

        if (!$self->channel_nicks->{ $channel }{ $nick }++) {
            $ircd->yield( daemon_cmd_join => $nick => $channel );
        }
    }

    my $publish = sub {
        my ($nick, $text) = @_;
        $ircd->yield( daemon_cmd_privmsg => $nick => $channel => $_ ) for
            split /\r?\n/, $text;
    };

    # encode('utf-8' がなぜか文字バケーション
    $text = encode( $self->client_encoding, $text ) unless $self->client_encoding =~ /utf-?8/i;

    if ($nick && $text) {
        $publish->( $nick => $text );
    }
    else {
        $publish->( $self->server_nick => $text );
    }
}

1;
