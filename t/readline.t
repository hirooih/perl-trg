# -*- perl -*-
#	readline.t - Test script for Term::ReadLine:GNU
#
#	$Id: readline.t,v 1.21 1998-03-26 14:14:58 hayashi Exp $
#
#	Copyright (c) 1996,1997,1998 Hiroo Hayashi.  All rights reserved.
#
#	This program is free software; you can redistribute it and/or
#	modify it under the same terms as Perl itself.

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl t/readline.t'

BEGIN {print "1..13\n";}
END {print "not ok 1\n" unless $loaded;}

$^W = 1;			# perl -w
use strict;
use vars qw($loaded);
eval "use ExtUtils::testlib;" or eval "use lib './blib';";
use Term::ReadLine;
use Term::ReadLine::Gnu qw(ISKMAP ISMACR ISFUNC);

$loaded = 1;
print "ok 1\n";

########################################################################
# test new method

my $t = new Term::ReadLine 'ReadLineTest';
print defined $t ? "ok 2\n" : "not ok 2\n";

########################################################################
# test ReadLine method

my $OUT = $t->OUT || \*STDOUT;

if ($t->ReadLine eq 'Term::ReadLine::Gnu') {
    print "ok 3\n";
} else {
    print "not ok 3\n";
    print $OUT ("Package name should be \`Term::ReadLine::Gnu\', but it is \`",
		$t->ReadLine, "\'\n");
}

########################################################################
# test Features method

my %features = %{ $t->Features };
if (%features) {
    my @f = %features;
    print "ok 4\n";
} else {
    print $OUT "No additional features present.\n";
    print "not ok 4\n";
}

########################################################################
# test Attribs method

my $a = $t->Attribs;
print defined $a ? "ok 5\n" : "not ok 5\n";

########################################################################
# test tied variable

# Version 2.0 is NOT supported.
print $a->{library_version} > 2.0 ? "ok 6\n" : "not ok 6\n";

########################################################################
# test key binding functions

# sample custom function (reverse a whole line)
sub reverse_line {
    my($count, $key) = @_;	# ignored in this sample function
    $a->{line_buffer} = reverse $a->{line_buffer};
}

sub display_readline_version {
    my($count, $key) = @_;	# ignored in this sample function
    print $OUT "GNU Readline Library version: $a->{library_version}\n";
    $t->on_new_line();
}

# From the GNU Readline Library Manual
# Invert the case of the COUNT following characters.
sub invert_case_line {
    my($count, $key) = @_;

    my $start = $a->{point};
    return 0 if ($start >= $a->{end});

    # Find the end of the range to modify.
    my $end = $start + $count;

    # Force it to be within range.
    if ($end > $a->{end}) {
	$end = $a->{end};
    } elsif ($end < 0) {
	$end = 0;
    }

    return 0 if $start == $end;

    if ($start > $end) {
	my $temp = $start;
	$start = $end;
	$end = $temp;
    }

    # Tell readline that we are modifying the line, so it will save
    # undo information.
    $t->modifying($start, $end);

    # I'm happy with Perl :-)
    substr($a->{line_buffer}, $start, $end-$start) =~ tr/a-zA-Z/A-Za-z/;

    # Move point to on top of the last character changed.
    $a->{point} = $count < 0 ? $start : $end - 1;
    return 0;
}

$t->add_defun('reverse-line', \&reverse_line, ord "\ct");
$t->bind_key(ord "\ct", 'reverse-line', 'emacs-ctlx');
$t->parse_and_bind('"\C-xt": reverse-line');

$t->add_defun('display-readline-version', \&display_readline_version);
$t->bind_key(ord "\cv", 'display-readline-version', 'emacs-ctlx');
$t->parse_and_bind('"\C-xv": display-readline-version');

$t->add_defun('invert-case-line', \&invert_case_line);
$t->bind_key(ord "c", 'invert-case-line', 'emacs-meta');

# make original map
my $helpmap = $t->make_bare_keymap();
$t->bind_key(ord "f", 'dump-functions', $helpmap);
$t->generic_bind(ISKMAP, "\e?", $helpmap);
$t->bind_key(ord "v", 'dump-variables', $helpmap);
# documented but not defined by GNU Readline 2.1
#$t->generic_bind(ISFUNC, "\e?m", 'dump-macros');

# bind macro
$t->generic_bind(ISMACR, "\e?i", "\ca[insert text from beginning of line]");

# convert control charactors to printable charactors (ex. "\cx" -> '\C-x')
sub toprint {
    join('',map{ord($_)<32 ? '\C-'.lc(chr(ord($_)+64)) : $_}(split('',$_[0])));
}

my %TYPE = (0 => 'Function', 1 => 'Keymap', 2 => 'Macro');

print $OUT "\n";
foreach ("\co", "\ct", "\cx",
	 "\cx\ct", "\cxt", "\cx\cv", "\cxv", "\ec",
	 "\e?f", "\e?v", "\e?i") {
    my ($p, $type) = $t->function_of_keyseq($_);
    printf $OUT "%-9s: ", toprint($_);
    (print "\n", next) unless defined $type;
    printf $OUT "%-8s : ", $TYPE{$type};
    if    ($type == ISFUNC) { print $OUT ($t->get_function_name($p)); }
    elsif ($type == ISKMAP) { print $OUT ($t->get_keymap_name($p)); }
    elsif ($type == ISMACR) { print $OUT (toprint($p)); }
    else { print $OUT "Error Illegal type value"; }
    print $OUT "\n";
}
my @keyseqs = $t->invoking_keyseqs('reverse-line');
print $OUT "reverse-line is bound to ", join(', ',@keyseqs), "\n";

print "ok 7\n";

########################################################################
# test history expansion

# goto short_cut;
# goto end_of_test;

print $OUT "\n# history expansion test\n# quit by EOF (\\C-d)\n";
$t->MinLine(1);
$t->stifle_history(5);
$a->{do_expand} = 1;
my ($nline, $line);
for ($nline = 1; defined($line = $t->readline("$nline>")); $nline++) {
    print $OUT "<<$line>>\n";
}
print $OUT "\n";
print "ok 8\n";

########################################################################
# test key unbinding functions

print $OUT "unbind \\C-t and \\C-xt\n";
$t->unbind_key(ord "\ct");
$t->unbind_key(ord "t", 'emacs-ctlx');

@keyseqs = $t->invoking_keyseqs('reverse-line');
print $OUT "reverse-line is bound to ", join(', ',@keyseqs), "\n";
print "ok 9\n";

########################################################################
# test custom completion function

$t->readline("filename completion (default)>", "this is default string");

$a->{completion_entry_function} = $a->{'username_completion_function'};
$t->readline("username completion>");

$a->{completion_word} = [qw(a list of words for completion)];
$a->{completion_entry_function} = $a->{'list_completion_function'};
$t->readline("list completion>");

$a->{completion_entry_function} = $a->{'filename_completion_function'};
$t->readline("filename completion>");

sub sample_completion {
    my ($text, $line, $start, $end) = @_;
    # If first word then username completion, else filename completion
    if (substr($line, 0, $start) =~ /^\s*$/) {
	return $t->completion_matches($text, $a->{'list_completion_function'});
    } else {
	return ();
    }
}

$a->{attempted_completion_function} = \&sample_completion;
$t->readline("list & filename completion>");
$a->{attempted_completion_function} = undef;

print "ok 10\n";

########################################################################
# test ornaments
#short_cut:
{
    local $^W = 0;		# Term::ReadLine is not waring flag free
    print $OUT "# ornaments test\n";
    print $OUT "# Note: Some function may not work on your terminal.\n";
    # Kterm seems to have a bug with 'ue' (End underlining) does not work\n";
    $t->ornaments(1);	# equivalent to 'us,ue,md,me'
    $t->readline("default ornaments (underline)>");
    # cf. man termcap(5)
    $t->ornaments('so,me,,');
    $t->readline("standout>");
    $t->ornaments('us,me,,');
    $t->readline("underlining>");
    $t->ornaments('mb,me,,');
    $t->readline("blinking>");
    $t->ornaments('md,me,,');
    $t->readline("bold>");
    $t->ornaments('mr,me,,');
    $t->readline("reverse>");
    $t->ornaments('vb,,,');
    $t->readline("visible bell>");
    $t->ornaments(0);
    print $OUT "# end of ornaments test\n";
}

print "ok 11\n";

########################################################################
# test rl_startup_hook

sub insert_string { $t->insert_text('insert text'); };
$a->{startup_hook} = \&insert_string;
$t->readline("rl_startup_hook test>");
$a->{startup_hook} = undef;

print "ok 12\n";

########################################################################
# test rl_getc_function and rl_getc()

sub uppercase {
#    my $FILE = $a->{instream};
#    return ord uc chr $t->getc($FILE);
    return ord uc chr $t->getc($a->{instream});
}

$a->{getc_function} = \&uppercase;
$t->readline("convert to uppercase>");
$a->{getc_function} = undef;

print "ok 13\n";

end_of_test:

exit 0;
