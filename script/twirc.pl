#!/usr/bin/env perl

use strict;
use warnings;

use Pod::Usage;
use Getopt::Long;

use FindBin::libs;

use YAML;
use Twirc;

GetOptions(
    \my %option,
    qw/config=s help/
);
pod2usage(1) if $option{help};

$option{config} ||=
    File::Spec->catfile( $FindBin::Bin, '..', 'twirc.yaml' );

my $twirc = Twirc->new(
    config => YAML::LoadFile( $option{config} )
);
$twirc->run;

=head1 NAME

twirc.pl - irc <-> twitter gateway using im

=head1 SYNOPSIS

    twirc.pl --config yourconfig.yaml

=head1 AUTHOR

Daisuke Murase <typester@cpan.org>

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
