# -*- perl -*-
#	utf8_binary.t --- Term::ReadLine:GNU UTF-8 binary string test script
#
#	$Id$
#
#	Copyright (c) 2016 Hiroo Hayashi.  All rights reserved.
#
#	This program is free software; you can redistribute it and/or
#	modify it under the same terms as Perl itself.

use strict;
use warnings;

use Test::More tests => 5;
my $ntest = 5;
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

# skip when PERL_UNICODE is set
# https://rt.cpan.org/Public/Bug/Display.html?id=114185
if (${^UNICODE} != 0) {
    diag "PERL_UNICODE is defined or -C option is specified. Skipped...";
    ok(1, 'skip') for 1..$ntest-1;
    exit 0;
}
ok(1, 'PERL_UNICODE is not defined');

my $line;
my @layers;
open (my $in, "<", "t/utf8.txt") or die "cannot open utf8.txt: $!";

if (0) {	# This may cause a fail.
    $line = <$in>; chomp($line);
    note $line;
    note Dumper($line, "漢字1");
    ok($line eq "漢字1", 'pre-read');
}

@layers = PerlIO::get_layers($in);
note 'i: ', join(':', @layers);
#is_deeply(\@layers, ['unix', 'perlio'], "input layers before 'new'");
@layers = PerlIO::get_layers(\*STDOUT);
note 'o: ', join(':', @layers);
#is_deeply(\@layers, ['unix', 'perlio'], "output layers before new'");

my $t = new Term::ReadLine 'ReadLineTest', $in, \*STDOUT;
print "\n";	# rl_initialize() outputs some escape characters in Term-ReadLine-Gnu less than 6.3, 
isa_ok($t, 'Term::ReadLine');

@layers = PerlIO::get_layers($t->IN);
note 'i: ', join(':', @layers);
#is_deeply(\@layers, ['unix', 'perlio', 'stdio'], "input layers after 'new'");
@layers = PerlIO::get_layers($t->OUT);
note 'o: ', join(':', @layers);
#is_deeply(\@layers, ['unix', 'perlio', 'stdio'], "output layers after 'new'");

# make the GNU Readline 8 bit through
$t->parse_and_bind('set input-meta on');
$t->parse_and_bind('set convert-meta off');
$t->parse_and_bind('set output-meta on');

$line = $t->readline("漢字> ");
note $line;
note Dumper($line, "漢字1");
ok($line eq "漢字1", 'UTF-8 binary string read');
ok(!utf8::is_utf8($line), 'not UTF-8 text string');

if (0) {	# This may cause a fail.
    $line = <$in>; chomp($line);
    note $line;
    note Dumper($line, "漢字2");
    ok($line eq "漢字2");

    $line = $t->readline("漢字> ");
    note $line;
    note Dumper($line, "漢字3");
    ok($line eq "漢字3");

    @layers = PerlIO::get_layers($in);      note 'i: ', join(':', @layers);
    @layers = PerlIO::get_layers(\*STDOUT); note 'o: ', join(':', @layers);
}

exit 0;
