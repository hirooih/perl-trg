use ExtUtils::MakeMaker;

# Modify 'LIBS' and/or 'INC' if you need.
WriteMakefile(
    'NAME'	=> 'Term::ReadLine::Gnu',
    'VERSION_FROM' => 'Gnu.pm',
    'LIBS'	=> ['-L/usr/local/gnu/lib -lreadline -ltermcap'],
    'DEFINE'	=> '',
    'INC'	=> '-I/usr/local/gnu/include',
    'dist'	=> {COMPRESS=>'gzip -9f', SUFFIX=>'gz'},
);
