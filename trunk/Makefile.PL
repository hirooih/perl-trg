#
#	Makefile.PL for Term::ReadLine::Gnu
#
#	$Id: Makefile.PL,v 1.10 1998-08-13 15:05:44 hayashi Exp $
#
#	Copyright (c) 1996,1997,1998 Hiroo Hayashi.  All rights reserved.
#		<hiroo.hayashi@computer.org>
#
#	This program is free software; you can redistribute it and/or
#	modify it under the same terms as Perl itself.
#
#	OS/2 support is contributed by Ilya Zakharevich.
#		<ilya@math.ohio-state.edu>

########################################################################
# Modify these variables if you need.
$libreadlinedir = '/usr/local/gnu/lib';	# for -L option
$increadlinedir = '/usr/local/gnu/inc';	# for -I option

########################################################################
use ExtUtils::MakeMaker;
use Config;

$defs = ($Config{strings} =~ m|/string.h$|) ? '-DHAVE_STRING_H' : '';

# Ignore outside of OS/2. Set to 1 if linking with readline.dll under
# OS/2.
# Check ftp://ftp.math.ohio-state.edu/pub/users/ilya/os2/
$os2_usedll = $Config{osname} eq 'os2';
if ($os2_usedll == 0) {
    $libs = '-lreadline -ltermcap';
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
system("$Config{cc} -I$increadlinedir $Config{ccflags} $defs $frlver -o rlver -L$libreadlinedir -lreadline -ltermcap $Config{ldflags}");
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

WriteMakefile(
    'NAME'	=> 'Term::ReadLine::Gnu',
    'VERSION_FROM' => 'Gnu.pm',
    'LIBS'	=> [ "-L$libreadlinedir $libs" ],
    'DEFINE'	=> $defs,
    ($os2_usedll ? 
	(
	IMPORTS	=> { xfree => 'emxlibcm.401' },	# Yuck!
	) : () ),
    'INC'	=> "-I$increadlinedir",
    'dist'	=> { COMPRESS => 'gzip -9f', SUFFIX => 'gz' },
    'clean'	=> { FILES => 'rlver.c rlver' },
);

# End of Makefile.PL
