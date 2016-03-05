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
use Test;
use utf8;
use open ':encoding(utf8)';
use open ':std';
use Data::Dumper;

# http://perldoc.perl.org/perllocale.html
use POSIX qw(locale_h);
use locale;

our ($loaded, $n);

BEGIN {
#    $ENV{PERL_RL} = 'Gnu';	# force to use Term::ReadLine::Gnu
    $ENV{LC_ALL} = 'en_US.utf8';
}
BEGIN { plan tests => 4 }
END {
    unless ($loaded) {
	print "not ok 1\tfail to loading\n";
	warn "\nPlease report the output of \'perl Makefile.PL\'\n\n"; 
    }
}

eval "use ExtUtils::testlib;" or eval "use lib './blib';";

use Term::ReadLine;
print "# I'm testing Term::ReadLine::Gnu version $Term::ReadLine::Gnu::VERSION\n";

$loaded = 1;
ok($loaded, 1);

my $old_locale = setlocale(LC_ALL, 'en_US.utf8');
if (!defined $old_locale) {
    print "The locale 'en_US.utf8' is not supported. Skipped...\n";
    ok(1); ok(1); ok(1);
    exit 0;
}

my $line;
my @layers;
open (my $in, "<", "t/utf8.txt") or die "cannot open utf8.txt: $!";

if (0) {	# why this fails?
    $line = <$in>; chomp($line);
    print $line, "\n";
    print Dumper($line, "漢字1");
    ok($line eq "漢字1");
}

@layers = PerlIO::get_layers($in);      print '#i: ', join(':', @layers), "\n";
@layers = PerlIO::get_layers(\*STDOUT); print '#o: ', join(':', @layers), "\n";
my $t = new Term::ReadLine 'ReadLineTest', $in, \*STDOUT;
ok(1);

@layers = PerlIO::get_layers($in);      print '#i: ', join(':', @layers), "\n";
@layers = PerlIO::get_layers(\*STDOUT); print '#o: ', join(':', @layers), "\n";

$line = $t->readline("漢字> ");
print $line, "\n";
print Dumper($line, "漢字1");
ok($line eq "漢字1");
ok(utf8::is_utf8($line));

if (0) {	# why this fails?
    $line = <$in>; chomp($line);
    print $line, "\n";
    print Dumper($line, "漢字2");
    ok($line eq "漢字2");

    $line = $t->readline("漢字> ");
    print $line, "\n";
    print Dumper($line, "漢字3");
    ok($line eq "漢字3");

    @layers = PerlIO::get_layers($in);      print '$in:    ', join(':', @layers), "\n";
    @layers = PerlIO::get_layers(\*STDOUT); print 'STDOUT: ', join(':', @layers), "\n";
}

exit 0;