#
#	Makefile.PL for Term::ReadLine::Gnu
#
#	$Id: Makefile.PL,v 1.4 1996-11-24 13:59:12 hayashi Exp $
#
#	Copyright (c) 1996 Hiroo Hayashi.  All rights reserved.
#
#	This program is free software; you can redistribute it and/or
#	modify it under the same terms as Perl itself.
#
#	OS/2 support is contributed by Ilya Zakharevich.
#		<ilya@math.ohio-state.edu>

use ExtUtils::MakeMaker;
use Config;

$defs = ($Config{strings} =~ m|/string.h$|) ? '-DHAVE_STRING_H' : '';

$os2_usedll = 0;		# Ignore outside of OS/2. Set to 1 if linking
				# with readline.dll under OS/2.
				# ftp.math.ohio-state.edu:/pub/users/ilya/os2
if ($os2_usedll == 0) {
    $libs = '-lreadline -ltermcap';
} else {
    $libs = '-lreadline_import';
}

# Modify 'LIBS' and/or 'INC' if you need.
WriteMakefile(
    'NAME'	=> 'Term::ReadLine::Gnu',
    'VERSION_FROM' => 'Gnu.pm',
    'LIBS'	=> [ "-L/usr/local/gnu/lib $libs" ],
    'DEFINE'	=> $defs,
    ($os2_usedll ? 
	(
	IMPORTS	=> { xfree => 'emxlibcm.401' },	# Yuck!
	) : () ),
    'INC'	=> '-I/usr/local/gnu/include',
    'dist'	=> { COMPRESS => 'gzip -9f', SUFFIX => 'gz' },
);
