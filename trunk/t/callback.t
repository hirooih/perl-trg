# -*- perl -*-
#	callback.t - Test script for Term::ReadLine:GNU callback function
#
#	$Id: callback.t,v 1.2 1999-04-04 11:24:44 hayashi Exp $
#
#	Copyright (c) 1999 Hiroo Hayashi.  All rights reserved.
#
#	This program is free software; you can redistribute it and/or
#	modify it under the same terms as Perl itself.

BEGIN {print "1..7\n"; $n = 1;}
END {print "not ok 1\tfail to loading\n" unless $loaded;}

my $verbose = defined @ARGV && ($ARGV[0] eq 'verbose');

$^W = 1;			# perl -w
use strict;
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

my ($IN, $OUT);
if ($verbose) {
    $IN = $attribs->{instream};
    $OUT = $attribs->{outstream};
} else {
    open(IN, 't/button.pl') or die "cannot open 't/button.pl': $!\n";
    $IN = \*IN;
    # $IN = \*DATA;		# does not work.  Why?
    open(NULL, '>/dev/null') or die "cannot open \`/dev/null\': $!\n";
    $attribs->{outstream} = $OUT = \*NULL;
}

########################################################################
# check Tk is installed
if (eval "use Tk; 1") {
    print "ok $n\tuse Tk\n"; $n++;
} else {
    print "ok $n\t# skipped since Tk is not installed.\n"; $n++;
    print "ok $n\t# skipped since Tk is not installed.\n"; $n++;
    print "ok $n\t# skipped since Tk is not installed.\n"; $n++;
    print "ok $n\t# skipped since Tk is not installed.\n"; $n++;
    exit 0;
}
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
