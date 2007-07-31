package Twirc;
use strict;
use warnings;
use base qw/Class::Accessor::Fast/;

our $VERSION = '0.01';

__PACKAGE__->mk_accessors(qw/config/);

use POE;

use Twirc::Jabber;
use Twirc::Server;
use Twirc::Ustream;

sub new {
    my $self = shift->SUPER::new( @_ > 1 ? {@_} : $_[0] );
}

sub run {
    my $self = shift;

    Twirc::Jabber->spawn( $self->config->{jabber} );
    Twirc::Server->spawn( $self->config->{ircd} );
    Twirc::Ustream->spawn( $self->config->{ustream} ) if $self->config->{ustream};
    POE::Kernel->run;
}

1;
