# -*- perl -*-
#	utf8_73984.t --- Term::ReadLine:GNU UTF-8 Test Script
#
#	Bug #73894 for Term-ReadLine-Gnu: using Term::ReadLine::Gnu
#	mocks binmoded (utf-8) IO
#	https://rt.cpan.org/Public/Bug/Display.html?id=73894
#
#	$Id: $
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
our ($loaded, $n);

BEGIN {
#    $ENV{PERL_RL} = 'Gnu';	# force to use Term::ReadLine::Gnu
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

my $line;
my @layers;
open (my $in, "<", "t/utf8.txt") or die "cannot open utf8.txt: $!";
@layers = PerlIO::get_layers(\*STDIN);  print 'STDIN:  ', join(':', @layers), "\n";
@layers = PerlIO::get_layers($in);      print '$in:    ', join(':', @layers), "\n";
@layers = PerlIO::get_layers(\*STDOUT); print 'STDOUT: ', join(':', @layers), "\n";

$line = <$in>; chomp($line);
print $line, "\n";
print Dumper($line, "漢字1");
ok($line eq "漢字1");

if (0) {
    my $t = new Term::ReadLine 'ReadLineTest', $in, \*STDOUT;
} else {
    Term::ReadLine::Gnu::Var::_rl_store_iostream($in, 0);
    binmode($in, ":pop");
    Term::ReadLine::Gnu::Var::_rl_store_iostream(\*STDOUT, 1);
    binmode(\*STDOUT, ":pop");
}
ok(1);

@layers = PerlIO::get_layers(\*STDIN);  print 'STDIN:  ', join(':', @layers), "\n";
@layers = PerlIO::get_layers($in);      print '$in:    ', join(':', @layers), "\n";
@layers = PerlIO::get_layers(\*STDOUT); print 'STDOUT: ', join(':', @layers), "\n";

$line = <$in>; chomp($line);
print $line, "\n";
print Dumper($line, "漢字2");
ok($line eq "漢字2");

@layers = PerlIO::get_layers(\*STDIN);  print 'STDIN:  ', join(':', @layers), "\n";
@layers = PerlIO::get_layers($in);      print '$in:    ', join(':', @layers), "\n";
@layers = PerlIO::get_layers(\*STDOUT); print 'STDOUT: ', join(':', @layers), "\n";

exit 0;
