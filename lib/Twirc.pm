package Twirc;
use Moose;

our $VERSION = '0.02';

use POE;

use Twirc::Jabber;
use Twirc::Server;

has config => (
    is  => 'rw',
    isa => 'HashRef',
);

has jabber => (
    is      => 'rw',
    lazy    => 1,
    default => sub {
        my $self = shift;
        Twirc::Jabber->new( $self->config->{jabber} );
    },
);

has ircd => (
    is      => 'rw',
    lazy    => 1,
    default => sub {
        my $self = shift;
        Twirc::Server->new(
            %{ $self->config->{ircd} },
            channels => $self->config->{channels},
        );
    },
);

__PACKAGE__->meta->make_immutable;

sub run {
    my $self = shift;

    $self->jabber->spawn;
    $self->ircd->spawn;

    POE::Kernel->run;
}

1;
