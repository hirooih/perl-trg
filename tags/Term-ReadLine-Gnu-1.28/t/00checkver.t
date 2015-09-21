# -*- perl -*-
#	00check.t - check versions
#
#	$Id$
#
#	Copyright (c) 2008 Hiroo Hayashi.  All rights reserved.
#
#	This program is free software; you can redistribute it and/or
#	modify it under the same terms as Perl itself.

BEGIN {
    $ENV{PERL_RL} = 'Gnu';	# force to use Term::ReadLine::Gnu
}
END {
    unless ($loaded) {
	print "not ok 1\tfail to loading\n";
	warn "\nPlease report the output of \'perl Makefile.PL\'\n\n"; 
    }
}

use strict;
use warnings;
use Test;
BEGIN { plan tests => 4 }
use vars qw($loaded);
eval "use ExtUtils::testlib;" or eval "use lib './blib';";

use Term::ReadLine;

print "# I'm testing Term::ReadLine::Gnu version $Term::ReadLine::Gnu::VERSION\n";

$loaded = 1;
ok($loaded, 1);

my $t = new Term::ReadLine 'ReadLineTest';
ok(1);
my $a = $t->Attribs;
ok(1);

print  "# OS: $^O\n";
print  "# Perl version: $]\n";
printf "# GNU Readline Library version: $a->{library_version}, 0x%X\n", $a->{readline_version};
print  "# \$TERM=$ENV{TERM}\n";

ok(1);

exit 0;

