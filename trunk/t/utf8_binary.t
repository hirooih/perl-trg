# -*- perl -*-
#	utf8_binary.t --- Term::ReadLine::Gnu UTF-8 binary string test script
#
#	$Id$
#
#	Copyright (c) 2016 Hiroo Hayashi.  All rights reserved.
#
#	This program is free software; you can redistribute it and/or
#	modify it under the same terms as Perl itself.

# The GNU Readline Library start supporting multibyte characters since
# version 4.3, and is still improving the support.
# If you want just read strings including mutibyte charactors
# (e.g. UTF-8), you may simply treat them as binary strings as shown this
# test.

use strict;
use warnings;

use constant NTEST => 12;
use Test::More tests => NTEST;
use Data::Dumper;

# redefine Test::Mode::note due to it requires Perl 5.10.1.
{
    no warnings 'redefine';
    sub note {
	my $msg = join('', @_);
	$msg =~ s{\n(?!\z)}{\n# }sg;
	print "# $msg" . ($msg =~ /\n$/ ? '' : "\n");
    }
}

BEGIN {
#    $ENV{PERL_RL} = 'Gnu';	# force to use Term::ReadLine::Gnu
}

use Term::ReadLine;
ok(1, 'load done');
note "I'm testing Term::ReadLine::Gnu version $Term::ReadLine::Gnu::VERSION";

my $verbose = scalar @ARGV && ($ARGV[0] eq 'verbose');

# skip when PERL_UNICODE is set
# https://rt.cpan.org/Public/Bug/Display.html?id=114185
if (${^UNICODE} != 0) {
    diag "PERL_UNICODE is defined or -C option is specified. Skipped...";
    ok(1, 'skip') for 1..(NTEST-1);
    exit 0;
}
ok(1, 'PERL_UNICODE is not defined');

my ($in, $line, @layers);
open ($in, "<", "t/utf8.txt") or die "cannot open utf8.txt: $!";

if (0) {	# This may cause a fail.
    $line = <$in>; chomp($line);
    note $line;
    note Dumper($line, "🐪");
    ok($line eq "🐪", 'pre-read');
}

my $expected = $] > 5.010 ? ['unix', 'perlio'] : ['stdio'];
@layers = PerlIO::get_layers($in);
note 'i: ', join(':', @layers);
is_deeply(\@layers, $expected, "input layers before 'new'");
@layers = PerlIO::get_layers(\*STDOUT);
note 'o: ', join(':', @layers);
is_deeply(\@layers, $expected, "output layers before 'new'");

my $t;
if ($verbose) {
    #$t = new Term::ReadLine 'ReadLineTest', \*STDIN, \*STDOUT;
    $t = new Term::ReadLine 'ReadLineTest';
} else {
    $t = new Term::ReadLine 'ReadLineTest', $in, \*STDOUT;
}
print "\n";	# rl_initialize() outputs some escape characters in Term-ReadLine-Gnu less than 6.3, 
isa_ok($t, 'Term::ReadLine');

$expected = $] > 5.010 ? ['unix', 'perlio', 'stdio'] : ['stdio'];
@layers = PerlIO::get_layers($t->IN);
note 'i: ', join(':', @layers);
is_deeply(\@layers, $expected, "input layers after 'new'");
@layers = PerlIO::get_layers($t->OUT);
note 'o: ', join(':', @layers);
is_deeply(\@layers, $expected, "output layers after 'new'");

# force the GNU Readline 8 bit through
if ($t->ReadLine eq 'Term::ReadLine::Gnu') {
    $t->parse_and_bind('set input-meta on');
    $t->parse_and_bind('set convert-meta off');
    $t->parse_and_bind('set output-meta on');
}

my $a = $t->Attribs;
# verbose mode
if ($verbose) {
    $a->{do_expand} = 1;
    while ($line = $t->readline("🐪🐪> ")) {
	note $line;
	note Dumper($line);
    }
    exit 0;
}

# UTF8 string input
$line = $t->readline("🐪🐪> ");
note $line;
note Dumper($line, "🐪");
ok($line eq "🐪", 'UTF-8 binary string read');
ok(!utf8::is_utf8($line), 'not UTF-8 text string: function');

# UTF8 string variable access
$a->{readline_name} = '🐪 🐪🐪 🐪🐪🐪';
$line = $a->{readline_name};
note $line;
note Dumper($line);
ok($line eq '🐪 🐪🐪 🐪🐪🐪', 'UTF-8 binary string variable');
ok(!utf8::is_utf8($line), 'not UTF-8 text string: variable');

# UTF-8 binary string does not work.
ok(reverse $line ne '🐪🐪🐪 🐪🐪 🐪', 'This does not work.');

if (0) {	# This may cause a fail.
    $line = <$in>; chomp($line);
    note $line;
    note Dumper($line, "🐪🐪");
    ok($line eq "🐪🐪");

    $line = $t->readline("🐪🐪🐪> ");
    note $line;
    note Dumper($line, "🐪🐪🐪");
    ok($line eq "🐪🐪🐪");

    @layers = PerlIO::get_layers($in);      note 'i: ', join(':', @layers);
    @layers = PerlIO::get_layers(\*STDOUT); note 'o: ', join(':', @layers);
}

exit 0;
