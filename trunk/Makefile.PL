use ExtUtils::MakeMaker;

# Modify 'LIBS' and/or 'INC' if you need.
WriteMakefile(
    'NAME'	=> 'Term::ReadLine::Gnu',
    'VERSION_FROM' => 'Gnu.pm',
    'LIBS'	=> ['-L/usr/local/gnu/lib -lreadline -ltermcap'],
# Comment out next line if strings.h is missing (Ex. Solaris 2.x)
#    'DEFINE'	=> '-DHAVE_STRING_H',
    'INC'	=> '-I/usr/local/gnu/include',
    'dist'	=> {COMPRESS=>'gzip -9f', SUFFIX=>'gz'},
);
