#
#	Makefile.PL for Term::ReadLine::Gnu
#
#	$Id: Makefile.PL,v 1.26 2003-03-16 19:03:04 hiroo Exp $
#
#	Copyright (c) 2002 Hiroo Hayashi.  All rights reserved.
#		<hiroo.hayashi@computer.org>
#
#	This program is free software; you can redistribute it and/or
#	modify it under the same terms as Perl itself.
#
#	OS/2 support is contributed by Ilya Zakharevich.
#		<ilya@math.ohio-state.edu>
#
# Usage: perl Makefile.PL [--prefix=...] [--includedir=...] [--libdir=...]
#		[OPTIMIZE=...]
########################################################################
use ExtUtils::MakeMaker;
use Config;
use Getopt::Long;

if ($Config{usesfio} eq 'true') {
    warn("** Your Perl is configured as \'usesfio\' equals true. **\n");
    warn("** The GNU Readline Library may not work with perl with sfio. **\n");
}

$defs = ($Config{strings} =~ m|/string.h$|) ? '-DHAVE_STRING_H' : '';

# Parse command line to specify paths for the GNU Readline Library
GetOptions("prefix=s" => \$prefix,
	   "libdir=s" => \$libdir,
	   "includedir=s" => \$includedir);
$libdir     = "$prefix/lib"     if (defined $prefix and ! defined $libdir);
$includedir = "$prefix/include" if (defined $prefix and ! defined $includedir);
$RLLIB = defined $libdir     ? "-L$libdir"     : '';
$RLINC = defined $includedir ? "-I$includedir" : '';

# Search libtermcap, libncurses, or libcurses in this order.
# I emulate the behavior of configure script for bash, and don't know
# why AIX prefers curses.
# libtermcap.a on HPUX cannot be used for dynamically linked binary.
$PREFER_CURSES = $Config{osname} eq 'aix' || $Config{osname} eq 'hpux';
$TERMCAP_LIB = (! $PREFER_CURSES && &search_lib('-ltermcap'))
    || &search_lib('-lncurses')
    || &search_lib('-lcurses');

die "Could not find neither libtermcap.a, libncurses.a, or libcurses.\n"
    unless $TERMCAP_LIB;

# Ignore outside of OS/2. Set to 1 if linking with readline.dll under
# OS/2.
# Check ftp://ftp.math.ohio-state.edu/pub/users/ilya/os2/
if ($Config{osname} ne 'os2') {
    $libs = "-lreadline $TERMCAP_LIB";
    $lddflags = '-static' if ($Config{osname} =~ /cygwin/i);
    # Latest Perl in FreeBSD does not need this hack. (Dec.2002)
    $libs .= ' -lcrypt' if ($Config{osname} =~ /freebsd/i);
} else {
    $libs = '-lreadline_import';
    $defs .= ' -DOS2_USEDLL';
}

#
# Check libreadline.a version
#
# Readline 4.2a introduced the macro
#	RL_READLINE_VERSION
#	RL_VERSION_MAJOR
#	RL_VERSION_MINOR
# Someday we don't need the following hack.
$frlver = 'rlver.c';

# make temp file
open(F, ">$frlver") || die "Cannot open $frlver:$!\n";
print F <<'EOF';
/* used by Makefile.pl to check the version of the GNU Readline Library */
#include <stdio.h>
#include <readline/readline.h>
main() { puts(rl_library_version); }
EOF
close(F);

# compile it
$comp_cmd = "$Config{cc} $RLINC $Config{ccflags} $defs $frlver -o rlver $RLLIB $lddflags $Config{ldflags} $libs";
print $comp_cmd, "\n";
system($comp_cmd);
if ($?) {
    die <<EOM;
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
Could not compile $frlver.

If you have installed the GNU Readline Library (libreadline.{a,so} and
readline/readline.h, etc.) on directories for which your perl is not
configured to search (refer the value of ccflags and libpath in the
output of `perl -V'), specify the paths as follows;

	perl Makefile.PL --includedir=/mydir/include --libdir=/mydir/lib
or
	perl Makefile.PL --prefix=/mydir

Note that the GNU Readline Library version 2.0 and earlier cause error
here.  Update it to version 2.1 and/or later.

Read INSTALL for more details.
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
EOM
}

# execute it and get version
chomp($rlver = `./rlver`);
print "It seems that you have the GNU Readline Library version $rlver.\n";
# $rlver may be '8.21-beta3' or '4.2a'
($rlmajorver, $rlminorver) = $rlver =~ /(\d+)\.(\d+)/;
$rl_readline_version = sprintf("0x%02x%02x", $rlmajorver, $rlminorver);
if ($rl_readline_version <= 0x0402) {
    $defs .= " -DRL_READLINE_VERSION=$rl_readline_version";
    $defs .= " -DRL_VERSION_MAJOR=$rlmajorver";
    $defs .= " -DRL_VERSION_MINOR=$rlminorver";
}

# generate a Makefile
WriteMakefile
    (
     NAME	  => 'Term::ReadLine::Gnu',
     VERSION_FROM => 'Gnu.pm',
     LIBS	  => [ "$RLLIB $libs" ],
     #LDFLAGS	  => "$RLLIB $Config{ldflags}",
     #LDDLFLAGS	  => "$RLLIB $lddflags $Config{lddlflags}",
     dynamic_lib  => { OTHERLDFLAGS => $lddflags },
     DEFINE	  => $defs,
     ($Config{osname} eq 'os2' ?
      (
       IMPORTS	=> { xfree => 'emxlibcm.401' },	# Yuck!
      ) : () ),
     INC	  => $RLINC,
     dist	  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz' },
     clean	  => { FILES => "rlver.c rlver$Config{_exe}" },
);

exit(0);

########################################################################
# Search a library '$lib' in $Config{libpth} directories, and return
# $lib if exist or undef unless exist.
#
# ExtUtils::MakeMaker::ext() do same job as this subroutine, but it
# warns unnecessary messages.
sub search_lib {
    my ($lib) = @_;
    unless ($lib =~ /^-l/) {
	warn "search_lib: illegal arguments, \`$lib\'.\n";
	return undef;
    }
    my $libbase = 'lib' . substr($lib, 2) . $Config{lib_ext};
    my $libbase_so = 'lib' . substr($lib, 2) . "." . $Config{so};
    foreach (split(' ', $Config{libpth})) {
	if (-f $_ . '/' . $libbase) {
#	    print "$_/$libbase\n";
	    print "Found \`$_/$libbase\'.\n";
	    return $lib;
	} elsif (-f $_ . '/' . $libbase_so) {
#	    print "$_/$libbase_so\n";
	    print "Found \`$_/$libbase_so\'.\n";
	    return $lib;
	}
    }
    return undef;
}

# End of Makefile.PL
