# -*- perl -*-
#	callback.t - Test script for Term::ReadLine:GNU callback function
#
#	$Id$
#
#	Copyright (c) 2014 Hiroo Hayashi.  All rights reserved.
#
#	This program is free software; you can redistribute it and/or
#	modify it under the same terms as Perl itself.

BEGIN {
    print "1..7\n"; $n = 1;
    $ENV{PERL_RL} = 'Gnu';	# force to use Term::ReadLine::Gnu
}
END {print "not ok 1\tfail to loading\n" unless $loaded;}

# 'define @ARGV' is deprecated
my $verbose = scalar @ARGV && ($ARGV[0] eq 'verbose');

use strict;
use warnings;
use vars qw($loaded $n);
eval "use ExtUtils::testlib;" or eval "use lib './blib';";
use Term::ReadLine;

$loaded = 1;
print "ok 1\tloading\n"; $n++;

########################################################################
# test new method

my $term = new Term::ReadLine 'ReadLineTest';
print defined $term ? "ok $n\n" : "not ok $n\n"; $n++;

my $attribs = $term->Attribs;
print defined $attribs ? "ok $n\n" : "not ok $n\n"; $n++;

my ($version) = $attribs->{library_version} =~ /(\d+\.\d+)/;

########################################################################
# check Tk is installed and X Window is available
#disable the warning, "Too late to run INIT block at..."

{
    no warnings 'uninitialized';
    if (eval "use Tk; 1" && $ENV{DISPLAY} ne '') {
	print "ok $n\tuse Tk\n"; $n++;
    } else {
	print "ok $n\t# skipped since Tk is not available.\n"; $n++;
	print "ok $n\t# skipped since Tk is not available.\n"; $n++;
	print "ok $n\t# skipped since Tk is not available.\n"; $n++;
	print "ok $n\t# skipped since Tk is not available.\n"; $n++;
	exit 0;
    }
}

########################################################################
my ($IN, $OUT);
if ($verbose) {
    # wait for Perl Tk script from tty
    $IN = $attribs->{instream};
    $OUT = $attribs->{outstream};
} else {
    # test automatically
    # to surpress warning on GRL 4.2a (and above?).
    $attribs->{prep_term_function} = sub {} if ($version > 4.1);

#    open(IN, 't/button.pl') or die "cannot open 't/button.pl': $!\n";
#    $IN = \*IN;
#    old Perl did not work with the next line...
    $IN = \*DATA;		# does not work.  Why?
    open(NULL, '>/dev/null') or die "cannot open \`/dev/null\': $!\n";
    $attribs->{outstream} = $OUT = \*NULL;
}

########################################################################
my $mw;
$mw = MainWindow->new();
$mw->protocol('WM_DELETE_WINDOW' => \&quit);

$attribs->{instream} = $IN;
$mw->fileevent($IN, 'readable', $attribs->{callback_read_char});
print "ok $n\tcallback_read_char\n"; $n++;

$term->callback_handler_install("> ", sub {
    my $line = shift;
    quit() unless defined $line;
    eval $line;
    print $OUT "$@\n" if $@;
});
print "ok $n\tcallback_handler_install\n"; $n++;

&MainLoop;

sub quit {
   $mw->fileevent($IN, 'readable', '');
   $term->callback_handler_remove();
   $mw->destroy;
   print "ok $n\n"; $n++;
   exit 0;
}

__END__
$b=$mw->Button(-text=>'hello',-command=>sub{print $OUT 'hello'})
$b->pack;
