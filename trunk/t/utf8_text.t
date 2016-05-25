# -*- perl -*-
#	utf8_text.t --- Term::ReadLine:GNU UTF-8 text string test script
#
#	$Id$
#
#	Copyright (c) 2016 Hiroo Hayashi.  All rights reserved.
#
#	This program is free software; you can redistribute it and/or
#	modify it under the same terms as Perl itself.

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
is_deeply(\@layers, ['unix', 'perlio', 'encoding(utf8)', 'utf8'], "input layers before 'new'");
@layers = PerlIO::get_layers(\*STDOUT);
is_deeply(\@layers, ['unix', 'perlio', 'encoding(utf8)', 'utf8'], "output layers before 'new'");

my $t = new Term::ReadLine 'ReadLineTest', $in, \*STDOUT;
# Note that the following line does not work.
# It is because 'use open' is lexically scoped and it does not affect
# the 'open /dev/tty' in Term::ReadLine::Gnu.
#my $t = new Term::ReadLine 'ReadLineTest';
print "\n";	# rl_initialize() outputs some escape characters in Term-ReadLine-Gnu less than 6.3, 
isa_ok($t, 'Term::ReadLine');

@layers = PerlIO::get_layers($t->IN);
is_deeply(\@layers, ['unix', 'perlio', 'encoding(utf8)', 'utf8'], "input layers after 'new'");
@layers = PerlIO::get_layers($t->OUT);
is_deeply(\@layers, ['unix', 'perlio', 'encoding(utf8)', 'utf8'], "output layers after 'new'");

$line = $t->readline("漢字> ");
note $line;
note Dumper($line, "漢字1");
ok($line eq "漢字1", 'UTF-8 text string read');
ok(utf8::is_utf8($line), 'UTF-8 text string');

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
