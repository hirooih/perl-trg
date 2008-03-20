# -*- perl -*-
#	00check.t - check versions
#
#	$Id: 00checkver.t,v 1.1 2008-03-20 13:50:26 hiroo Exp $
#
#	Copyright (c) 2008 Hiroo Hayashi.  All rights reserved.
#
#	This program is free software; you can redistribute it and/or
#	modify it under the same terms as Perl itself.

BEGIN {
    print "1..2\n"; $n = 1;
    $ENV{PERL_RL} = 'Gnu';	# force to use Term::ReadLine::Gnu
}
END {
    unless ($loaded) {
	print "not ok 1\tfail to loading\n";
	warn "\nPlease report the output of \'perl Makefile.PL\'\n\n"; 
    }
}

$^W = 1;			# perl -w
use strict;
use vars qw($loaded $n);
eval "use ExtUtils::testlib;" or eval "use lib './blib';";
use Term::ReadLine;
use Term::ReadLine::Gnu;

$loaded = 1;
print "ok 1\tloading\n"; $n++;

my $t = new Term::ReadLine 'ReadLineTest';

print "OS: $^O\nPerl version: $]\n";
$t->rl_call_function('display-readline-version');
print "ok 2\tdone\n"; $n++;

exit 0;

