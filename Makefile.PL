#
#	Makefile.PL for Term::ReadLine::Gnu
#
#	$Id: Makefile.PL,v 1.17 1999-06-23 12:50:28 hayashi Exp $
#
#	Copyright (c) 1999 Hiroo Hayashi.  All rights reserved.
#		<hiroo.hayashi@computer.org>
#
#	This program is free software; you can redistribute it and/or
#	modify it under the same terms as Perl itself.
#
#	OS/2 support is contributed by Ilya Zakharevich.
#		<ilya@math.ohio-state.edu>

########################################################################
# Modify these variables if you need.
$libreadlinedir = '/usr/local/gnu/lib';		# for -L option
$increadlinedir = '/usr/local/gnu/include';	# for -I option

########################################################################
use ExtUtils::MakeMaker;
use Config;

if ($Config{usesfio} eq 'true') {
    warn("** Your Perl is configured as \'usesfio\' equals true. **\n");
    warn("** The GNU Readline Library may not work with perl with sfio. **\n");
}

$defs = ($Config{strings} =~ m|/string.h$|) ? '-DHAVE_STRING_H' : '';

# Search libtermcap, libncurses, or libcurses in this order.
# I emulate the behavior of configure script for bash, and don't know
# why AIX prefers curses.
# libtermcap.a on HPUX cannot be used for dynamically linked binary.
$PREFER_CURSES = $Config{osname} eq 'aix' or $Config{osname} eq 'hpux';
$TERMCAP_LIB = (! $PREFER_CURSES && &search_lib('-ltermcap'))
    || &search_lib('-lncurses')
    || &search_lib('-lcurses');

die "Cannot find neither libtermcap.a, libncureses.a, or libcurses.\n"
    unless $TERMCAP_LIB;

# Ignore outside of OS/2. Set to 1 if linking with readline.dll under
# OS/2.
# Check ftp://ftp.math.ohio-state.edu/pub/users/ilya/os2/
$os2_usedll = $Config{osname} eq 'os2';
if ($Config{osname} =~ /cygwin/i) {
    $libs = "-lreadline $TERMCAP_LIB -luser32";
} elsif ($os2_usedll == 0) {
    $libs = "-lreadline $TERMCAP_LIB";
} else {
    $libs = '-lreadline_import';
    $defs .= ' -DOS2_USEDLL';
}

#
# Check libreadline.a version
#
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
system("$Config{cc} -I$increadlinedir $Config{ccflags} $defs $frlver -o rlver -L$libreadlinedir $libs $Config{ldflags}");
if ($?) {
    die <<EOM;
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
Cannot compile $frlver.

Check variables, \$increadlinedir and \$libreadlinedir, in Makefile.PL.

Note that GNU Readline Library version 2.0 and earlier cause error here,
Read INSTALL for more details.
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
EOM
}

# execute it and get version
chomp($rlver = `./rlver`);
print "It seems that you have the GNU Readline Library version $rlver.\n";
($rlmajorver, $rlminorver) = split('\.', $rlver);
$defs .= " -DRLMAJORVER=$rlmajorver -DRLMINORVER=$rlminorver";

# generate a Makefile
WriteMakefile(
    'NAME'	=> 'Term::ReadLine::Gnu',
    'VERSION_FROM' => 'Gnu.pm',
    'LIBS'	=> [ $libs ],
    'LDFLAGS'	=> "-L$libreadlinedir $Config{ldflags}",
    'LDDLFLAGS'	=> "-L$libreadlinedir $Config{lddlflags}",
    'DEFINE'	=> $defs,
    ($os2_usedll ? 
	(
	IMPORTS	=> { xfree => 'emxlibcm.401' },	# Yuck!
	) : () ),
    'INC'	=> "-I$increadlinedir",
    'dist'	=> { COMPRESS => 'gzip -9f', SUFFIX => 'gz' },
    'clean'	=> { FILES => "rlver.c rlver$Config{_exe}" },
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
#	print "$_/$libbase\n";
	if (-f $_ . '/' . $libbase) {
	    print "Found \`$_/$libbase\'.\n";
	    return $lib;
	}
#	print "$_/$libbase_so\n";
	if (-f $_ . '/' . $libbase_so) {
	    print "Found \`$_/$libbase_so\'.\n";
	    return $lib;
	}
    }
    return undef;
}

# End of Makefile.PL
