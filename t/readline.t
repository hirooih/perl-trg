# -*- perl -*-
#	readline.t - Test script for Term::ReadLine:GNU
#
#	$Id: readline.t,v 1.26 1999-03-04 16:18:25 hayashi Exp $
#
#	Copyright (c) 1996-1999 Hiroo Hayashi.  All rights reserved.
#
#	This program is free software; you can redistribute it and/or
#	modify it under the same terms as Perl itself.

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl t/readline.t'

BEGIN {print "1..26\n"; $n = 1;}
END {print "not ok 1\n" unless $loaded;}

my $verbose = defined @ARGV && ($ARGV[0] eq 'verbose');

$^W = 1;			# perl -w
use strict;
use vars qw($loaded $n);
eval "use ExtUtils::testlib;" or eval "use lib './blib';";
use Term::ReadLine;
use Term::ReadLine::Gnu qw(ISKMAP ISMACR ISFUNC);

$loaded = 1;
print "ok $n\n"; $n++;

########################################################################
# test new method

my $t = new Term::ReadLine 'ReadLineTest';
print defined $t ? "ok $n\n" : "not ok $n\n"; $n++;

my $OUT;
if ($verbose) {
    $OUT = $t->OUT || \*STDOUT;
} else {
    open(NULL, '>/dev/null') or die "cannot open \`/dev/null\': $!\n";
    $OUT = \*NULL;
    $t->Attribs->{outstream} = \*NULL;
}

########################################################################
# test ReadLine method

if ($t->ReadLine eq 'Term::ReadLine::Gnu') {
    print "ok $n\n"; $n++;
} else {
    print "not ok $n"; $n++;
    print("\tPackage name should be \`Term::ReadLine::Gnu\', but it is \`",
	  $t->ReadLine, "\'\n");
}

########################################################################
# test Features method

my %features = %{ $t->Features };
if (%features) {
    my @f = %features;
    print "ok $n\n"; $n++;
} else {
    print "not ok $n"; $n++;
    print "\tNo additional features present.\n";
}

########################################################################
# test Attribs method

my $a = $t->Attribs;
print defined $a ? "ok $n\n" : "not ok $n\n"; $n++;

########################################################################
# test tied variable

my ($version) = $a->{library_version} =~ /(\d+\.\d+)/;

# Version 2.0 is NOT supported.
print $version > 2.0 ? "ok $n\n" : "not ok $n\n"; $n++;

########################################################################
# test key binding functions

my ($M, $F, $B, $MF, $MB, $E, $A, $H, $D, $I);

# bind basic functions since ~/.inputrc may change their binding.
$t->generic_bind(ISFUNC, $M  = "\cC", 'accept-line');
$t->generic_bind(ISFUNC, $F  = "\cF", 'forward-char');
$t->generic_bind(ISFUNC, $B  = "\cB", 'backward-char');
$t->generic_bind(ISFUNC, $MF = "\ef", 'forward-word');
$t->generic_bind(ISFUNC, $MB = "\eb", 'backward-word');
$t->generic_bind(ISFUNC, $E  = "\cE", 'end-of-line');
$t->generic_bind(ISFUNC, $A  = "\cA", 'beginning-of-line');
$t->generic_bind(ISFUNC, $H  = "\cH", 'backward-delete-char');
$t->generic_bind(ISFUNC, $D  = "\cD", 'delete-char');
$t->generic_bind(ISFUNC, $I  = "\cI", 'complete');

sub is_boundp {
    my ($seq, $fname) = @_;
    my ($fn, $type) = $t->function_of_keyseq($seq);
    return ($t->get_function_name($fn) eq $fname
	    && $type == ISFUNC);
}

if (is_boundp($M, 'accept-line')
    && is_boundp($F,  'forward-char')
    && is_boundp($B,  'backward-char')
    && is_boundp($MF, 'forward-word')
    && is_boundp($MB, 'backward-word')
    && is_boundp($E,  'end-of-line')
    && is_boundp($A,  'beginning-of-line')
    && is_boundp($H,  'backward-delete-char')
    && is_boundp($D,  'delete-char')
    && is_boundp($I,  'complete')) {
    print "ok $n\n"; $n++;
} else {    
    print "not ok $n\n"; $n++;
}

########################################################################
# sample custom function (reverse a whole line)
sub reverse_line {
    my($count, $key) = @_;	# ignored in this sample function
    $a->{line_buffer} = reverse $a->{line_buffer};
}

sub display_readline_version {
    my($count, $key) = @_;	# ignored in this sample function
    print $OUT "\nGNU Readline Library version: $a->{library_version}\n";
    print $OUT "Term::ReadLine::Gnu version: $Term::ReadLine::Gnu::VERSION\n";
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

# sample function of rl_message()
sub change_ornaments {
    my($count, $key) = @_;	# ignored in this sample function
    $t->save_prompt;
    $t->message("[S]tandout, [U]nderlining, [B]old, [R]everse, [V]isible bell");
    my $c = chr $t->read_key;
    if ($c =~ /s/i) {
	$t->ornaments('so,me,,');
    } elsif ($c =~ /u/i) {
	$t->ornaments('us,me,,');
    } elsif ($c =~ /b/i) {
	$t->ornaments('md,me,,');
    } elsif ($c =~ /r/i) {
	$t->ornaments('mr,me,,');
    } elsif ($c =~ /v/i) {
	$t->ornaments('vb,,,');
    } else {
	$t->ding;
    }
    $t->restore_prompt;
    $t->clear_message;
}

$t->add_defun('reverse-line', \&reverse_line, ord "\ct");

$t->add_defun('display-readline-version', \&display_readline_version);
$t->bind_key(ord "\cv", 'display-readline-version', 'emacs-ctlx');
$t->parse_and_bind('"\C-xv": display-readline-version');

$t->add_defun('invert-case-line', \&invert_case_line);
$t->bind_key(ord "c", 'invert-case-line', 'emacs-meta');

$t->add_defun('change-ornaments', \&change_ornaments);
$t->bind_key(ord "o", 'change-ornaments', 'emacs-meta');

# make original map
my $helpmap = $t->make_bare_keymap();
$t->bind_key(ord "f", 'dump-functions', $helpmap);
$t->generic_bind(ISKMAP, "\e?", $helpmap);
$t->bind_key(ord "v", 'dump-variables', $helpmap);
# 'dump-macros' is documented but not defined by GNU Readline 2.1
$t->generic_bind(ISFUNC, "\e?m", 'dump-macros') if $version > 2.1;

# bind macro
my $mymacro = "\ca[insert text from beginning of line]";
$t->generic_bind(ISMACR, "\e?i", $mymacro);

# convert control charactors to printable charactors (ex. "\cx" -> '\C-x')
sub toprint {
    join('',
	 map{$_ eq "\e" ? '\M-': ord($_)<32 ? '\C-'.lc(chr(ord($_)+64)) : $_}
	 (split('',$_[0])));
}

my %TYPE = (0 => 'Function', 1 => 'Keymap', 2 => 'Macro');

print $OUT "\n";
foreach ("\co", "\ct", "\cx",
	 "\cx\cv", "\cxv", "\ec",
	 "\e?f", "\e?v", "\e?i", "\eo") {
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
# my @keyseqs = $t->invoking_keyseqs('reverse-line');
# print $OUT "reverse-line is bound to ", join(', ',@keyseqs), "\n";

{
    my ($fn, $ty);
    # check keymap binding
    # Can I assume that nobody rebind "\C-x" ?
    ($fn, $ty) = $t->function_of_keyseq("\cX");
    if ($t->get_keymap_name($fn) eq 'emacs-ctlx'
	&& $ty == ISKMAP) {
	print "ok $n\n"; $n++;
    } else {    
	print "not ok $n\n"; $n++;
    }
    # check macro binding
    ($fn, $ty) = $t->function_of_keyseq("\e?i");
    if ($fn eq $mymacro && $ty == ISMACR) {
	print "ok $n\n"; $n++;
    } else {    
	print "not ok $n\n"; $n++;
    }
}

# check function binding
if (is_boundp("\cT", 'reverse-line')
    && is_boundp("\cX\cV", 'display-readline-version')
    && is_boundp("\cXv",   'display-readline-version')
    && is_boundp("\ec",    'invert-case-line')
    && is_boundp("\eo",    'change-ornaments')
    && is_boundp("\e?f",   'dump-functions')
    && is_boundp("\e?v",   'dump-variables')
    && is_boundp("\e?m",   'dump-macros')) {
    print "ok $n\n"; $n++;
} else {    
    print "not ok $n\n"; $n++;
}

########################################################################
my ($INSTR, $line);
# simulate key input by using a variable 'rl_getc_function'
$a->{getc_function} = sub {
    unless (length $INSTR) {
	print $OUT "Error: getc_function: insufficient string, \`\$INSTR\'.";
	undef $a->{getc_function};
	return 0;
    }
    my $c  = substr $INSTR, 0, 1; # the first char of $INSTR
    $INSTR = substr $INSTR, 1;	# rest of $INSTR
    return ord $c;
} unless $verbose;

$INSTR = "abcdefgh${M}";
$line = $t->readline("self insert> ");
print $line eq 'abcdefgh' ? "ok $n\n" : "not ok $n\n"; $n++;

$INSTR = "${A}e${F}f${B}g${E}h${H} ij kl${MB}${MB}m${D}n${M}";
$line = $t->readline("cursor move> ", 'abcd'); # default string
print $line eq 'eagfbcd mnj kl' ? "ok $n\n" : "not ok $n\n"; $n++;

# test reverse_line, display_readline_version, invert_case_line
$INSTR = "\cXvabcdefgh XYZ\e6${B}\e4\ec\cT${M}";
$line = $t->readline("custom commands> ");
print $line eq 'ZYx HGfedcba' ? "ok $n\n" : "not ok $n\n"; $n++;

# test macro, change_ornaments
$INSTR = "1234\e?i\eoB${M}${M}";
$line = $t->readline("keyboard macro> ");
print $line eq "[insert text from beginning of line]1234"
    ? "ok $n\n" : "not ok $n\n"; $n++;

$INSTR = "${M}";
$line = $t->readline("bold face prompt> ");
print $line eq '' ? "ok $n\n" : "not ok $n\n"; $n++;

########################################################################
# test history expansion

$t->ornaments(0);		# ornaments off

#print $OUT "\n# history expansion test\n# quit by EOF (\\C-d)\n";
$a->{do_expand} = 1;
$t->MinLine(4);

sub prompt {
    # equivalent with "$nline = $t->where_history + 1"
    my $nline = $a->{history_base} + $a->{history_length};
    "$nline> ";
}

$INSTR = "!1${M}";
$line = $t->readline(prompt());
print $line eq 'abcdefgh' ? "ok $n\n" : "not ok $n\n"; $n++;

$INSTR = "123${M}";		# too short
$line = $t->readline(prompt());
$INSTR = "!!${M}";
$line = $t->readline(prompt());
print $line eq 'abcdefgh' ? "ok $n\n" : "not ok $n\n"; $n++;

$INSTR = "1234${M}";
$line = $t->readline(prompt());
$INSTR = "!!${M}";
$line = $t->readline(prompt());
print $line eq '1234' ? "ok $n\n" : "not ok $n\n"; $n++;

########################################################################
# test key unbinding functions

#print $OUT "unbind \\C-t, \\M-?f, \\M-?v, \\C-xv, and \\C-x\\C-v\n";
$t->unbind_key(ord "\ct");	# reverse-line
$t->unbind_key(ord "f", $helpmap); # dump-function
$t->unbind_key(ord "v", 'emacs-ctlx'); # display-readline-version
$t->unbind_command_in_map('display-readline-version', 'emacs-ctlx');
$t->unbind_function_in_map($t->named_function('dump-variables'), $helpmap);

my @keyseqs = ($t->invoking_keyseqs('reverse-line'),
	       $t->invoking_keyseqs('dump-functions'),
	       $t->invoking_keyseqs('display-readline-version'),
	       $t->invoking_keyseqs('dump-variables'));
unless (@keyseqs) {
    print "ok $n\n"; $n++;
} else {    
    print "not ok $n\n"; $n++;
}

########################################################################
# test custom completion function

$INSTR = "t/comp${I}R${I}${M}";
$line = $t->readline("filename completion (default)>");
print $line eq 't/comptest/README ' ? "ok $n\n" : "not ok $n\n"; $n++;

$a->{completion_entry_function} = $a->{'username_completion_function'};
$INSTR = "root${I}${M}";
$line = $t->readline("username completion>");
print $line eq 'root ' ? "ok $n\n" : "not ok $n\n"; $n++;

$a->{completion_word} = [qw(a list of words for completion and another word)];
$a->{completion_entry_function} = $a->{'list_completion_function'};
print $OUT "given list is: a list of words for completion and another word\n";
$INSTR = "a${I}${I}n${I}${I}o${I}${M}";
$line = $t->readline("list completion>");
print $line eq 'another ' ? "ok $n\n" : "not ok $n\n"; $n++;


$a->{completion_entry_function} = $a->{'filename_completion_function'};
$INSTR = "t/comp${I}${I}${I}0${I}${I}1${I}${I}${M}";
$line = $t->readline("filename completion>");
print $line eq 't/comptest/0123' ? "ok $n\n" : "not ok $n\n"; $n++;

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
print $OUT "given list is: a list of words for completion and another word\n";
$INSTR = "li${I}t/comp${I}${I}${I}0${I}${I}2${I}${M}";
$line = $t->readline("list & filename completion>");
print $line eq 'list t/comptest/023456 ' ? "ok $n\n" : "not ok $n\n"; $n++;

$a->{attempted_completion_function} = undef;

########################################################################
# test ornaments
{
    local $^W = 0;		# Term::Cap.pm warns for unsupported function
    $INSTR = "${M}${M}${M}${M}${M}${M}${M}";
    print $OUT "# ornaments test\n";
    print $OUT "# Note: Some function may not work on your terminal.\n";
    # Kterm seems to have a bug with 'ue' (End underlining) does not work\n";
    $t->ornaments(1);	# equivalent to 'us,ue,md,me'
    print $OUT "\n" unless defined $t->readline("default ornaments (underline)>");
    # cf. man termcap(5)
    $t->ornaments('so,me,,');
    print $OUT "\n" unless defined $t->readline("standout>");
    $t->ornaments('us,me,,');
    print $OUT "\n" unless defined $t->readline("underlining>");
    $t->ornaments('mb,me,,');
    print $OUT "\n" unless defined $t->readline("blinking>");
    $t->ornaments('md,me,,');
    print $OUT "\n" unless defined $t->readline("bold>");
    $t->ornaments('mr,me,,');
    print $OUT "\n" unless defined $t->readline("reverse>");
    $t->ornaments('vb,,,');
    print $OUT "\n" unless defined $t->readline("visible bell>");
    $t->ornaments(0);
    print $OUT "# end of ornaments test\n";
}

print "ok $n\n"; $n++;

########################################################################
# test rl_startup_hook

#sub move_cursor { $a->{point} = 10; };
#$a->{startup_hook} = \&move_cursor;
$a->{startup_hook} = sub { $a->{point} = 10; };
$INSTR = "insert${M}";
$line = $t->readline("rl_startup_hook test>", "cursor is, <- here");
print $line eq 'cursor is,insert <- here' ? "ok $n\n" : "not ok $n\n"; $n++;
$a->{startup_hook} = undef;

########################################################################
# test rl_getc_function and rl_getc()

sub uppercase {
#    my $FILE = $a->{instream};
#    return ord uc chr $t->getc($FILE);
    return ord uc chr $t->getc($a->{instream});
}

if ($verbose) {
    $a->{getc_function} = \&uppercase;
    print $OUT "\n" unless defined $t->readline("convert to uppercase>");
    $a->{getc_function} = undef;
}

########################################################################
print STDERR <<EOM unless $verbose;
ok
	Try \`perl -Mblib t/readline.t verbose\', if you will.
EOM
exit 0;
