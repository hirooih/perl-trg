# -*- perl -*-
#	utf8_text.t --- Term::ReadLine:GNU UTF-8 text string test script
#
#	$Id$
#
#	Copyright (c) 2016 Hiroo Hayashi.  All rights reserved.
#
#	This program is free software; you can redistribute it and/or
#	modify it under the same terms as Perl itself.

# The GNU Readline Library start supporting multibyte characters since
# version 4.3, and is still improving the support.

use strict;
use warnings;

# convert into UTF-8 text strings
use utf8;
use open ':std', ':encoding(utf8)';

# This must follow UTF-8 setting.
# See 'CAVEATS and NOTES' in http://perldoc.perl.org/Test/More.html for details.
use Test::More tests => 10;
my $ntest = 10;
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
    $ENV{LC_ALL} = 'en_US.UTF-8';
}

# 'define @ARGV' is deprecated
my $verbose = scalar @ARGV && ($ARGV[0] eq 'verbose');

use Term::ReadLine;
ok(1, 'load done');
note "I'm testing Term::ReadLine::Gnu version $Term::ReadLine::Gnu::VERSION";

# check locale setting because the following tests depend on locale feature.
use Config;
if (! $Config{d_setlocale}) {
    diag "d_setlocale is not defined. Skipped...";
    ok(1, 'skip') for 1..$ntest-2;
    exit 0;
}
ok(1, '$Config{d_setlocale}');

# http://perldoc.perl.org/perllocale.html
use POSIX qw(locale_h);
use locale;
my $old_locale = setlocale(LC_ALL, 'en_US.UTF-8');
if (!defined $old_locale) {
    diag "The locale 'en_US.UTF-8' is not supported. Skipped...";
    ok(1, 'skip') for 1..$ntest-3;
    exit 0;
}
ok(1, 'setlocale');

my ($in, $line, @layers);
if ($verbose) {
    $in = \*STDIN;
} else {
    open ($in, "<", "t/utf8.txt") or die "cannot open utf8.txt: $!";
}
if (0) {	# This may cause a fail.
    $line = <$in>; chomp($line);
    note $line;
    note Dumper($line, "🐪");
    ok($line eq "🐪", 'pre-read');
}

my @expected = $] > 5.010 ? ('unix', 'perlio', 'encoding(utf8)', 'utf8') : ('stdio', 'encoding(utf8)', 'utf8');
@layers = PerlIO::get_layers($in);
note 'i: ', join(':', @layers);
is_deeply(\@layers, , \@expected, "input layers before 'new'");
@layers = PerlIO::get_layers(\*STDOUT);
note 'o: ', join(':', @layers);
is_deeply(\@layers, \@expected, "output layers before 'new'");

my $t = new Term::ReadLine 'ReadLineTest', $in, \*STDOUT;
# Note that the following line does not work.
# It is because 'use open' is lexically scoped and it does not affect
# the 'open /dev/tty' in Term::ReadLine::Gnu.
#my $t = new Term::ReadLine 'ReadLineTest';
print "\n";	# rl_initialize() outputs some escape characters in Term-ReadLine-Gnu less than 6.3, 
isa_ok($t, 'Term::ReadLine');

@layers = PerlIO::get_layers($t->IN);
note 'i: ', join(':', @layers);
is_deeply(\@layers, \@expected, "input layers after 'new'");
@layers = PerlIO::get_layers($t->OUT);
note 'o: ', join(':', @layers);
is_deeply(\@layers, \@expected, "output layers after 'new'");

# force the GNU Readline 8 bit through
$t->parse_and_bind('set input-meta on');
$t->parse_and_bind('set convert-meta off');
$t->parse_and_bind('set output-meta on');

if ($verbose) {
    while ($line = $t->readline("🐪🐪> ")) {
	note $line;
	note Dumper($line);
    }
    exit 0;
}

$line = $t->readline("🐪🐪> ");
note $line;
note Dumper($line, "🐪");
ok($line eq "🐪", 'UTF-8 text string read');
ok(utf8::is_utf8($line), 'UTF-8 text string');

note "This does work: ", scalar reverse('🐪 🐪🐪 🐪🐪🐪');

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
