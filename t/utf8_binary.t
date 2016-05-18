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

use Test::More tests => 7;
my $ntest = 7;
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

# skip when PERL_UNICODE is set
# https://rt.cpan.org/Public/Bug/Display.html?id=114185
if (${^UNICODE} != 0) {
    diag "PERL_UNICODE is defined or -C option is specified. Skipped...";
    ok(1, 'skip') for 1..$ntest-1;
    exit 0;
}
ok(1, 'PERL_UNICODE is not defined');

# check locale setting
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

@layers = PerlIO::get_layers($in);      note 'i: ', join(':', @layers);
@layers = PerlIO::get_layers(\*STDOUT); note 'o: ', join(':', @layers);
my $t = new Term::ReadLine 'ReadLineTest', $in, \*STDOUT;
print "\n";	# rl_initialize() outputs some escape characters in Term-ReadLine-Gnu less than 6.3, 
isa_ok($t, 'Term::ReadLine');

@layers = PerlIO::get_layers($in);      note 'i: ', join(':', @layers);
@layers = PerlIO::get_layers(\*STDOUT); note 'o: ', join(':', @layers);

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
