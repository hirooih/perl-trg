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

use Test::More tests => 4;
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

my $line;
my @layers;
open (my $in, "<", "t/utf8.txt") or die "cannot open utf8.txt: $!";
@layers = PerlIO::get_layers(\*STDIN);  note 'STDIN:  ', join(':', @layers);
@layers = PerlIO::get_layers($in);      note '$in:    ', join(':', @layers);
@layers = PerlIO::get_layers(\*STDOUT); note 'STDOUT: ', join(':', @layers);

$line = <$in>; chomp($line);
note $line;
note Dumper($line, "漢字1");
ok($line eq "漢字1", 'pre-read');

if (0) {
    my $t = new Term::ReadLine 'ReadLineTest', $in, \*STDOUT;
} else {
    Term::ReadLine::Gnu::Var::_rl_store_iostream($in, 0);
    binmode($in, ":pop") if $] > 5.010;
    Term::ReadLine::Gnu::Var::_rl_store_iostream(\*STDOUT, 1);
    binmode(\*STDOUT, ":pop") if $] > 5.010;
}
ok(1, 'rl_store_iostream');

@layers = PerlIO::get_layers(\*STDIN);  note 'STDIN:  ', join(':', @layers);
@layers = PerlIO::get_layers($in);      note '$in:    ', join(':', @layers);
@layers = PerlIO::get_layers(\*STDOUT); note 'STDOUT: ', join(':', @layers);

$line = <$in>; chomp($line);
note $line;
note Dumper($line, "漢字2");
ok($line eq "漢字2", 'post-read');

@layers = PerlIO::get_layers(\*STDIN);  note 'STDIN:  ', join(':', @layers);
@layers = PerlIO::get_layers($in);      note '$in:    ', join(':', @layers);
@layers = PerlIO::get_layers(\*STDOUT); note 'STDOUT: ', join(':', @layers);

exit 0;
