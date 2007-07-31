package Twirc::Ustream;
use strict;
use warnings;

use base qw/Class::Accessor::Fast/;
__PACKAGE__->mk_accessors(qw/username password channels irc/);

use POE qw/Component::IRC/;

sub spawn {
    my $self = shift->SUPER::new(@_);

    POE::Session->create(
        object_states => [
            $self => [qw/_start irc_001 _default say/],
        ],
    );
}

sub _start {
    my ($self, $kernel) = @_[OBJECT, KERNEL];

    $kernel->alias_set('ustream');
    $self->{irc} = POE::Component::IRC->spawn(
        server => 'chat1.ustream.tv',
        port   => 6667,
        nick   => $self->username,
        $self->password ? ( password => $self->password ) : (),
    );

    $kernel->post( $self->irc->session_id => register => 'all' );
    $kernel->post( $self->irc->session_id => connect => {} );
}

sub irc_001 {
    my ($self, $kernel) = @_[OBJECT, KERNEL];
    $kernel->post( $self->irc->session_id => join => $_ ) for @{ $self->channels || [] };
}

sub say {
    my ($self, $kernel, $what) = @_[OBJECT, KERNEL, ARG0];
    $kernel->post( $self->irc->session_id => privmsg => $_ => $what ) for @{ $self->channels || [] };
}

sub _default {
    my ( $event, $args ) = @_[ ARG0 .. $#_ ];
    my @output = ("$event: ");

    foreach my $arg (@$args) {
        if ( ref($arg) eq 'ARRAY' ) {
            push( @output, "[" . join( " ,", @$arg ) . "]" );
        }
        else {
            push( @output, "'$arg'" );
        }
    }
    print STDOUT join ' ', @output, "\n";
    return 0;
}

1;
