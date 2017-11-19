# -*- perl -*-
#	02test_use.t - give up on a dumb terminal
#
#	$Id: 00checkver.t 518 2016-05-18 16:33:37Z hayashi $
#
#	Copyright (c) 2017 Hiroo Hayashi.  All rights reserved.
#
#	This program is free software; you can redistribute it and/or
#	modify it under the same terms as Perl itself.

use strict;
use warnings;
use Test::More tests => 2;
use vars qw($loaded);

BEGIN {
    $ENV{PERL_RL} = 'Gnu';	# force to use Term::ReadLine::Gnu
    $ENV{TERM} = 'dumb';
}
END {
    unless ($loaded) {
	ok(0, 'fail before loading');
	diag "\nPlease report the output of \'perl Makefile.PL\'\n"; 
    }
}

use Term::ReadLine;
ok(1, 'load done');
$loaded = 1;

my $t = new Term::ReadLine 'ReadLineTest';
isa_ok($t, 'Term::ReadLine::Stub');

print  "# \$TERM=$ENV{TERM}\n";

exit 0;

