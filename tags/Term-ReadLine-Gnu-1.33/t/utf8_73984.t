# -*- perl -*-
#	utf8_73984.t --- Term::ReadLine:GNU UTF-8 Test Script
#
#	Bug #73894 for Term-ReadLine-Gnu: using Term::ReadLine::Gnu
#	mocks binmoded (utf-8) IO
#	https://rt.cpan.org/Public/Bug/Display.html?id=73894
#
#	$Id$
#
#	Copyright (c) 2016 Hiroo Hayashi.  All rights reserved.
#
#	This program is free software; you can redistribute it and/or
#	modify it under the same terms as Perl itself.

use strict;
use warnings;

use utf8;
use open ':std', ':encoding(utf8)';

use Test::More tests => 13;
use Data::Dumper;

# redefine Test::Mode::note due to it requires Perl 5.10.1.
no warnings 'redefine';
sub note {
    my $msg = join('', @_);
    $msg =~ s{\n(?!\z)}{\n# }sg;
    print "# $msg" . ($msg =~ /\n$/ ? '' : "\n");
}
use warnings 'redefine';

BEGIN {
    $ENV{PERL_RL} = 'Gnu';	# force to use Term::ReadLine::Gnu
}

use Term::ReadLine;
ok(1, 'load done');
note "I'm testing Term::ReadLine::Gnu version $Term::ReadLine::Gnu::VERSION";

my @expected = $] >= 5.010 ? ('unix', 'perlio', 'encoding(utf8)', 'utf8') : ('stdio', 'encoding(utf8)', 'utf8');
my $line;
my @layers;
open (my $in, "<", "t/utf8.txt") or die "cannot open utf8.txt: $!";
@layers = PerlIO::get_layers(\*STDIN);  note 'STDIN:  ', join(':', @layers);
is_deeply(\@layers, , \@expected, '\*STDIN layers before _rl_store_iostream');
@layers = PerlIO::get_layers($in);      note '$in:    ', join(':', @layers);
is_deeply(\@layers, , \@expected, '$in layers before _rl_store_iostream');
@layers = PerlIO::get_layers(\*STDOUT); note 'STDOUT: ', join(':', @layers);
is_deeply(\@layers, , \@expected, '\*STDOUT layers before _rl_store_iostream');

$line = <$in>; chomp($line);
note $line;
note Dumper($line, "🐪");
ok($line eq "🐪", 'pre-read');

if (0) {
    my $t = new Term::ReadLine 'ReadLineTest', $in, \*STDOUT;
} else {
    # Perl 5.10 and later have to pop after calling PerlIO_importFILE
    Term::ReadLine::Gnu::Var::_rl_store_iostream($in, 0);
    binmode($in, ":pop") if $] >= 5.010;
    Term::ReadLine::Gnu::Var::_rl_store_iostream(\*STDOUT, 1);
    binmode(\*STDOUT, ":pop") if $] >= 5.010;
}
ok(1, 'rl_store_iostream');

@layers = PerlIO::get_layers(\*STDIN);  note 'STDIN:  ', join(':', @layers);
is_deeply(\@layers, , \@expected, '\*STDIN layers after _rl_store_iostream 1');
@layers = PerlIO::get_layers($in);      note '$in:    ', join(':', @layers);
is_deeply(\@layers, , \@expected, '$in layers after _rl_store_iostream 1');
@layers = PerlIO::get_layers(\*STDOUT); note 'STDOUT: ', join(':', @layers);
is_deeply(\@layers, , \@expected, '\*STDOUT layers after _rl_store_iostream 1');

$line = <$in>; chomp($line);
note $line;
note Dumper($line, "🐪🐪");
ok($line eq "🐪🐪", 'post-read');

@layers = PerlIO::get_layers(\*STDIN);  note 'STDIN:  ', join(':', @layers);
is_deeply(\@layers, , \@expected, '\*STDIN layers after _rl_store_iostream 2');
@layers = PerlIO::get_layers($in);      note '$in:    ', join(':', @layers);
is_deeply(\@layers, , \@expected, '$in layers after _rl_store_iostream 2');
@layers = PerlIO::get_layers(\*STDOUT); note 'STDOUT: ', join(':', @layers);
is_deeply(\@layers, , \@expected, '\*STDOUT layers after _rl_store_iostream 2');

exit 0;
