# -*- perl -*-
#	readline.t - Test script for Term::ReadLine:GNU
#
#	$Id: readline.t,v 1.20 1998-03-26 14:00:10 hayashi Exp $
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

my $term = new Term::ReadLine 'ReadLineTest';
print defined $term ? "ok 2\n" : "not ok 2\n";

########################################################################
# test ReadLine method

my $OUT = $term->OUT || \*STDOUT;

if ($term->ReadLine eq 'Term::ReadLine::Gnu') {
    print "ok 3\n";
} else {
    print "not ok 3\n";
    print $OUT ("Package name should be \`Term::ReadLine::Gnu\', but it is \`",
		$term->ReadLine, "\'\n");
}

########################################################################
# test Features method

my %features = %{ $term->Features };
if (%features) {
    my @f = %features;
    print "ok 4\n";
} else {
    print $OUT "No additional features present.\n";
    print "not ok 4\n";
}

########################################################################
# test Attribs method

my $attribs = $term->Attribs;
print defined $attribs ? "ok 5\n" : "not ok 5\n";

########################################################################
# test tied variable

# Version 2.0 is NOT supported.
print $attribs->{library_version} > 2.0 ? "ok 6\n" : "not ok 6\n";

########################################################################
# test key binding functions

# sample custom function (reverse a whole line)
sub reverse_line {
    my($count, $key) = @_;	# ignored in this sample function
    $attribs->{line_buffer} = reverse $attribs->{line_buffer};
}

sub display_readline_version {
    my($count, $key) = @_;	# ignored in this sample function
    print $OUT "GNU Readline Library version: $attribs->{library_version}\n";
    $term->on_new_line();
}

# From the GNU Readline Library Manual
# Invert the case of the COUNT following characters.
sub invert_case_line {
    my($count, $key) = @_;

    my $start = $attribs->{point};
    return 0 if ($start >= $attribs->{end});

    # Find the end of the range to modify.
    my $end = $start + $count;

    # Force it to be within range.
    if ($end > $attribs->{end}) {
	$end = $attribs->{end};
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
    $term->modifying($start, $end);

    # I'm happy with Perl :-)
    substr($attribs->{line_buffer}, $start, $end-$start) =~ tr/a-zA-Z/A-Za-z/;

    # Move point to on top of the last character changed.
    $attribs->{point} = $count < 0 ? $start : $end - 1;
    return 0;
}

$term->add_defun('reverse-line', \&reverse_line, ord "\ct");
$term->bind_key(ord "\ct", 'reverse-line', 'emacs-ctlx');
$term->parse_and_bind('"\C-xt": reverse-line');

$term->add_defun('display-readline-version', \&display_readline_version);
$term->bind_key(ord "\cv", 'display-readline-version', 'emacs-ctlx');
$term->parse_and_bind('"\C-xv": display-readline-version');

$term->add_defun('invert-case-line', \&invert_case_line);
$term->bind_key(ord "c", 'invert-case-line', 'emacs-meta');

# make original map
my $helpmap = $term->make_bare_keymap();
$term->bind_key(ord "f", 'dump-functions', $helpmap);
$term->generic_bind(ISKMAP, "\e?", $helpmap);
$term->bind_key(ord "v", 'dump-variables', $helpmap);
# documented but not defined by GNU Readline 2.1
#$term->generic_bind(ISFUNC, "\e?m", 'dump-macros');

# bind macro
$term->generic_bind(ISMACR, "\e?i", "\ca[insert text from beginning of line]");

# convert control charactors to printable charactors (ex. "\cx" -> '\C-x')
sub toprint {
    join('',map{ord($_)<32 ? '\C-'.lc(chr(ord($_)+64)) : $_}(split('',$_[0])));
}

my %TYPE = (0 => 'Function', 1 => 'Keymap', 2 => 'Macro');

print $OUT "\n";
foreach ("\co", "\ct", "\cx",
	 "\cx\ct", "\cxt", "\cx\cv", "\cxv", "\ec",
	 "\e?f", "\e?v", "\e?i") {
    my ($p, $type) = $term->function_of_keyseq($_);
    printf $OUT "%-9s: ", toprint($_);
    (print "\n", next) unless defined $type;
    printf $OUT "%-8s : ", $TYPE{$type};
    if    ($type == ISFUNC) { print $OUT ($term->get_function_name($p)); }
    elsif ($type == ISKMAP) { print $OUT ($term->get_keymap_name($p)); }
    elsif ($type == ISMACR) { print $OUT (toprint($p)); }
    else { print $OUT "Error Illegal type value"; }
    print $OUT "\n";
}
my @keyseqs = $term->invoking_keyseqs('reverse-line');
print $OUT "reverse-line is bound to ", join(', ',@keyseqs), "\n";

print "ok 7\n";

########################################################################
# test history expansion

# goto short_cut;
# goto end_of_test;

print $OUT "\n# history expansion test\n";
print $OUT "# quit by EOF (\\C-d)\n";
$term->MinLine(1);
$term->stifle_history(5);
$attribs->{do_expand} = 1;
my ($nline, $line);
for ($nline = 1;
     defined($line = $term->readline("$nline>"));
     $nline++) {
    print $OUT "<<$line>>\n";
}
print $OUT "\n";
print "ok 8\n";

########################################################################
# test key unbinding functions

print $OUT "unbind \\C-t and \\C-xt\n";
$term->unbind_key(ord "\ct");
$term->unbind_key(ord "t", 'emacs-ctlx');

@keyseqs = $term->invoking_keyseqs('reverse-line');
print $OUT "reverse-line is bound to ", join(', ',@keyseqs), "\n";
print "ok 9\n";

########################################################################
# test custom completion function

$term->readline("filename completion (default)>", "this is default string");

$attribs->{completion_entry_function} =
    $attribs->{'username_completion_function'};
$term->readline("username completion>");

$attribs->{completion_word} =
    [qw(list of words which you want to use for completion)];
$attribs->{completion_entry_function} = $attribs->{'list_completion_function'};
$term->readline("list completion>");

$attribs->{completion_entry_function} =
    $attribs->{'filename_completion_function'};
$term->readline("filename completion>");

sub sample_completion {
    my ($text, $line, $start, $end) = @_;
    # If first word then username completion, else filename completion
    if (substr($line, 0, $start) =~ /^\s*$/) {
	return $term->completion_matches($text,
					 $attribs->{'list_completion_function'});
    } else {
	return ();
    }
}

$attribs->{attempted_completion_function} = \&sample_completion;
$term->readline("list & filename completion>");
$attribs->{attempted_completion_function} = undef;

print "ok 10\n";

########################################################################
# test ornaments
#short_cut:
{
    local $^W = 0;		# Term::ReadLine is not waring flag free
    print $OUT "# ornaments test:\n";
    # Kterm seems to have a bug with 'ue' (End underlining) does not work\n";
    $term->ornaments(1);	# equivalent to 'us,ue,md,me'
    $term->readline("default ornaments (underline)>");
    # cf. man termcap(5)
    $term->ornaments('so,me,,');
    $term->readline("standout>");
    $term->ornaments('us,me,,');
    $term->readline("underlining>");
    $term->ornaments('mb,me,,');
    $term->readline("blinking>");
    $term->ornaments('md,me,,');
    $term->readline("bold>");
    $term->ornaments('mr,me,,');
    $term->readline("reverse>");
    $term->ornaments('vb,,,');
    $term->readline("visible bell>");
    $term->ornaments(0);
    print $OUT "# end of ornaments test\n";
}

print "ok 11\n";

########################################################################
# test rl_startup_hook

sub insert_string { $term->insert_text('insert text'); };
$attribs->{startup_hook} = \&insert_string;
$term->readline("rl_startup_hook test>");
$attribs->{startup_hook} = undef;

print "ok 12\n";

########################################################################
# test rl_getc_function and rl_getc()

sub uppercase {
    my $FILE = $attribs->{instream};
    return ord uc chr $term->getc($FILE);
#    return ord uc chr $term->getc($attribs->{instream}); # Why does this cause error?
}

$attribs->{getc_function} = \&uppercase;
$term->readline("convert to uppercase>");
$attribs->{getc_function} = undef;

print "ok 13\n";

end_of_test:

exit 0;
