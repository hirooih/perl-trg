# -*- perl -*-
#	readline.t - Test script for Term::ReadLine:GNU
#
#	$Id: readline.t,v 1.36 1999-05-19 15:32:19 hayashi Exp $
#
#	Copyright (c) 1996-1999 Hiroo Hayashi.  All rights reserved.
#
#	This program is free software; you can redistribute it and/or
#	modify it under the same terms as Perl itself.

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl t/readline.t'

BEGIN {print "1..89\n"; $n = 1;}
END {print "not ok 1\tfail to loading\n" unless $loaded;}

my $verbose = defined @ARGV && ($ARGV[0] eq 'verbose');

$^W = 1;			# perl -w
use strict;
use vars qw($loaded $n);
eval "use ExtUtils::testlib;" or eval "use lib './blib';";
use Term::ReadLine;
use Term::ReadLine::Gnu qw(ISKMAP ISMACR ISFUNC);

$loaded = 1;
print "ok 1\tloading\n"; $n++;


# Perl-5.005 and later has Test.pm, but I define this here to support
# older version.
my $res;
my $ok = 1;
sub ok {
    my $what = shift || '';

    if ($res) {
	print "ok $n\t$what\n";
    } else {
	print "not ok $n\t$what";
	print @_ ? "\t@_\n" : "\n";
	$ok = 0;
    }
    $n++;
}

########################################################################
# test new method

$ENV{'INPUTRC'} = '/dev/null';	# stop reading ~/.inputrc

my $t = new Term::ReadLine 'ReadLineTest';
$res =  defined $t; ok('new');

my $OUT;
if ($verbose) {
    $OUT = $t->Attribs->{outstream};
} else {
    open(NULL, '>/dev/null') or die "cannot open \`/dev/null\': $!\n";
    $OUT = \*NULL;
    $t->Attribs->{outstream} = \*NULL;
}

########################################################################
# test ReadLine method

$res = $t->ReadLine eq 'Term::ReadLine::Gnu';
ok('ReadLine method',
   "\tPackage name should be \`Term::ReadLine::Gnu\', but it is \`",
   $t->ReadLine, "\'\n");

########################################################################
# test Features method

my %features = %{ $t->Features };
$res = %features;
ok('Features method',"\tNo additional features present.\n");

########################################################################
# test Attribs method

my $a = $t->Attribs;
$res = defined $a; ok('Attrib method');

########################################################################
# 2.3 Readline Variables

my ($version) = $a->{library_version} =~ /(\d+\.\d+)/;

# Version 2.0 is NOT supported.
$res = $version > 2.0; ok('rl_version');

# check the values of initialized variables
$res = $a->{line_buffer} eq '';			ok;
$res = $a->{point} == 0;			ok;
$res = $a->{end} == 0;				ok;
$res = $a->{mark} == 0;				ok;
$res = $a->{done} == 0;				ok;
$res = $a->{pending_input} == 0;		ok('pending_input');
$res = $a->{erase_empty_line} == 0;		ok;
$res = ! defined($a->{prompt});			ok;
$res = ! defined($a->{terminal_name});		ok;
$res = $a->{readline_name} eq 'ReadLineTest';	ok('readline_name');

# rl_instream, rl_outstream

# The following variables will be tested later.
#	rl_startup_hook, rl_pre_input_hook, rl_event_hook,
#	rl_getc_function, rl_redisplay_function

# not defined here
$res = ! defined($a->{executing_keymap});	ok('executing_keymap');
# anonymous keymap
$res = defined($a->{binding_keymap});		ok('binding_keymap');

########################################################################
# 2.4 Readline Convenience Functions

########################################################################
# define some custom functions

sub reverse_line {		# reverse a whole line
    my($count, $key) = @_;	# ignored in this sample function
    
    $t->modifying(0, $a->{end}); # save undo information
    $a->{line_buffer} = reverse $a->{line_buffer};
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

########################################################################
# 2.4.1 Naming a Function

my ($func, $type);

# test add_defun
$res = (! defined($t->named_function('reverse-line'))
	&& ! defined($t->named_function('invert-case-line'))
	&& defined($t->named_function('operate-and-get-next'))
	&& defined($t->named_function('display-readline-version'))
	&& defined($t->named_function('change-ornaments')));
ok('add_defun');

($func, $type) = $t->function_of_keyseq("\ct");
$res = $type == ISFUNC && $t->get_function_name($func) eq 'transpose-chars';
ok;

$t->add_defun('reverse-line',		  \&reverse_line, ord "\ct");
$t->add_defun('invert-case-line',	  \&invert_case_line);

$res = (defined($t->named_function('reverse-line'))
	&& defined($t->named_function('invert-case-line'))
	&& defined($t->named_function('operate-and-get-next'))
	&& defined($t->named_function('display-readline-version'))
	&& defined($t->named_function('change-ornaments')));
ok;

($func, $type) = $t->function_of_keyseq("\ct");
$res = $type == ISFUNC && $t->get_function_name($func) eq 'reverse-line';
ok;

########################################################################
# 2.4.2 Selecting a Keymap

# test rl_make_bare_keymap, rl_copy_keymap, rl_make_keymap, rl_discard_keymap
my $baremap = $t->make_bare_keymap;
$t->bind_key(ord "a", 'abort', $baremap);
my $copymap = $t->copy_keymap($baremap);
$t->bind_key(ord "b", 'abort', $baremap);
my $normmap = $t->make_keymap;

$res = (($t->get_function_name(($t->function_of_keyseq('a', $baremap))[0])
	 eq 'abort')
	&& ($t->get_function_name(($t->function_of_keyseq('b', $baremap))[0])
	    eq 'abort')
	&& ($t->get_function_name(($t->function_of_keyseq('a', $copymap))[0])
	    eq 'abort')
	&& ! defined($t->function_of_keyseq('b', $copymap))
	&& ($t->get_function_name(($t->function_of_keyseq('a', $normmap))[0])
	    eq 'self-insert'));
ok('bind_key');

$t->discard_keymap($baremap);
$t->discard_keymap($copymap);
$t->discard_keymap($normmap);

# test rl_get_keymap, rl_set_keymap,
#	rl_get_keymap_by_name, rl_get_keymap_name
$res = $t->get_keymap_name($t->get_keymap) eq 'emacs';
ok;

$t->set_keymap('vi');
$res = $t->get_keymap_name($t->get_keymap) eq 'vi';
ok;

# equivalent to $t->set_keymap('emacs');
$t->set_keymap($t->get_keymap_by_name('emacs'));
$res = $t->get_keymap_name($t->get_keymap) eq 'emacs';
ok;

########################################################################
# 2.4.3 Binding Keys

#print $t->get_keymap_name($a->{executing_keymap}), "\n";
#print $t->get_keymap_name($a->{binding_keymap}), "\n";

# test rl_bind_key (rl_bind_key_in_map), rl_generic_bind, rl_parse_and_bind
# define subroutine to use again later
my ($helpmap, $mymacro);
sub bind_my_function {
    $t->bind_key(ord "\ct", 'reverse-line');
    $t->bind_key(ord "\cv", 'display-readline-version', 'emacs-ctlx');
    $t->parse_and_bind('"\C-xv": display-readline-version');
    $t->bind_key(ord "c", 'invert-case-line', 'emacs-meta');
    $t->bind_key(ord "o", 'change-ornaments', 'emacs-meta');
    
    # make original map
    $helpmap = $t->make_bare_keymap();
    $t->bind_key(ord "f", 'dump-functions', $helpmap);
    $t->generic_bind(ISKMAP, "\e?", $helpmap);
    $t->bind_key(ord "v", 'dump-variables', $helpmap);
    # 'dump-macros' is documented but not defined by GNU Readline 2.1
    $t->generic_bind(ISFUNC, "\e?m", 'dump-macros') if $version > 2.1;
    
    # bind macro
    $mymacro = "\ca[insert text from beginning of line]";
    $t->generic_bind(ISMACR, "\e?i", $mymacro);
}

bind_my_function;		# do bind

{
    my ($fn, $ty);
    # check keymap binding
    ($fn, $ty) = $t->function_of_keyseq("\cX");
    $res = $t->get_keymap_name($fn) eq 'emacs-ctlx' && $ty == ISKMAP;
    ok('binding keys');

    # check macro binding
    ($fn, $ty) = $t->function_of_keyseq("\e?i");
    $res = $fn eq $mymacro && $ty == ISMACR;
    ok;
}

# check function binding
$res = (is_boundp("\cT", 'reverse-line')
	&& is_boundp("\cX\cV", 'display-readline-version')
	&& is_boundp("\cXv",   'display-readline-version')
	&& is_boundp("\ec",    'invert-case-line')
	&& is_boundp("\eo",    'change-ornaments')
	&& is_boundp("\e?f",   'dump-functions')
	&& is_boundp("\e?v",   'dump-variables')
	&& is_boundp("\e?m",   'dump-macros'));
ok;

# test rl_read_init_file
$res = $t->read_init_file('t/inputrc') == 0;
ok('rl_read_init_file');

$res = (is_boundp("a", 'abort')
	&& is_boundp("b", 'abort')
	&& is_boundp("c", 'self-insert'));
ok;

# resume
$t->bind_key(ord "a", 'self-insert');
$t->bind_key(ord "b", 'self-insert');
$res = (is_boundp("a", 'self-insert')
	&& is_boundp("b", 'self-insert'));
ok;

# test rl_unbind_key (rl_unbind_key_in_map),
#	rl_unbind_command_in_map, rl_unbind_function_in_map
$t->unbind_key(ord "\ct");	# reverse-line
$t->unbind_key(ord "f", $helpmap); # dump-function
$t->unbind_key(ord "v", 'emacs-ctlx'); # display-readline-version
$t->unbind_command_in_map('display-readline-version', 'emacs-ctlx');
$t->unbind_function_in_map($t->named_function('dump-variables'), $helpmap);

my @keyseqs = ($t->invoking_keyseqs('reverse-line'),
	       $t->invoking_keyseqs('dump-functions'),
	       $t->invoking_keyseqs('display-readline-version'),
	       $t->invoking_keyseqs('dump-variables'));
$res = scalar @keyseqs == 0; ok('unbind_key',"@keyseqs");

########################################################################
# 2.4.4 Associating Function Names and Bindings

bind_my_function;		# do bind

# rl_named_function, rl_function_of_keyseq are tested above

@keyseqs = $t->invoking_keyseqs('abort', 'emacs-ctlx');
$res = "\\C-g" eq "@keyseqs";
ok('invoking_keyseqs');

# rl_function_dumper, rl_list_funmap_names will be tested in interructive test.

########################################################################
# 2.4.5 Allowing Undoing

########################################################################
# 2.4.6 Redisplay

########################################################################
# 2.4.7 Modifying Text

########################################################################
# 2.4.8 Utility Functions

########################################################################
# 2.4.9 Alternate Interface

########################################################################
# 2.5 Readline Signal Handling
$res = $a->{catch_signals} == 1;		ok('catch_signals');
$res = $a->{catch_sigwinch} == 1;		ok('catch_sigwinch');

########################################################################
# 2.6 Custom Completers
# 2.6.1 How Completing Works
# 2.6.2 Completion Functions
# 2.6.3 Completion Variables
$res = ! defined $a->{completion_entry_function};	ok;
$res = ! defined $a->{attempted_completion_function};	ok;
$res = ! defined $a->{filename_quoting_function};	ok;
$res = ! defined $a->{filename_dequoting_function};	ok;
$res = ! defined $a->{char_is_quoted_p};		ok;
$res = $a->{completion_query_items} == 100;		ok;
$res = ($a->{basic_word_break_characters}
	eq " \t\n\"\\'`\@\$><=;|&{(");			ok;
$res = $a->{basic_quote_characters} eq "\"'";		ok;
$res = ($a->{completer_word_break_characters}
	eq " \t\n\"\\'`\@\$><=;|&{(");			ok;
$res = ! defined $a->{completer_quote_characters};	ok;
$res = ! defined $a->{filename_quote_characters};	ok;
$res = ! defined $a->{special_prefixes};		ok;
$res = $a->{completion_append_character} eq " ";	ok;
$res = $a->{ignore_completion_duplicates} == 1;		ok;
$res = $a->{filename_completion_desired} == 0;		ok;
$res = $a->{filename_quoting_desired} == 1;		ok;
$res = $a->{inhibit_completion} == 0;			ok;
$res = ! defined $a->{ignore_some_completions_function};ok;
$res = ! defined $a->{directory_completions_hook};	ok;
$res = ! defined $a->{completions_display_matches_hook};ok;


########################################################################

$t->parse_and_bind('set bell-style none'); # make readline quiet

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
};

# check some key binding used by following test
sub is_boundp {
    my ($seq, $fname) = @_;
    my ($fn, $type) = $t->function_of_keyseq($seq);
    return ($t->get_function_name($fn) eq $fname
	    && $type == ISFUNC);
}

$res = (is_boundp("\cM", 'accept-line')
	&& is_boundp("\cF", 'forward-char')
	&& is_boundp("\cB", 'backward-char')
	&& is_boundp("\ef", 'forward-word')
	&& is_boundp("\eb", 'backward-word')
	&& is_boundp("\cE", 'end-of-line')
	&& is_boundp("\cA", 'beginning-of-line')
	&& is_boundp("\cH", 'backward-delete-char')
	&& is_boundp("\cD", 'delete-char')
	&& is_boundp("\cI", 'complete'));
ok('default key binding',
   "Default key binding is changed?  Some of following test will fail.");

$INSTR = "abcdefgh\cM";
$line = $t->readline("self insert> ");
$res = $line eq 'abcdefgh'; ok('self insert', $line);

$INSTR = "\cAe\cFf\cBg\cEh\cH ij kl\eb\ebm\cDn\cM";
$line = $t->readline("cursor move> ", 'abcd'); # default string
$res = $line eq 'eagfbcd mnj kl'; ok('cursor move', $line);

# test reverse_line, display_readline_version, invert_case_line
$INSTR = "\cXvabcdefgh XYZ\e6\cB\e4\ec\cT\cM";
$line = $t->readline("custom commands> ");
$res = $line eq 'ZYx HGfedcba'; ok('custom commands', $line);

# test undo of reverse_line
$INSTR = "abcdefgh\cTi\c_\c_\cM";
$line = $t->readline("test undo> ");
$res = $line eq 'abcdefgh'; ok('undo', $line);

# test macro, change_ornaments
$INSTR = "1234\e?i\eoB\cM\cM";
$line = $t->readline("keyboard macro> ");
$res = $line eq "[insert text from beginning of line]1234"; ok('macro', $line);
$INSTR = "\cM";
$line = $t->readline("bold face prompt> ");
$res = $line eq ''; ok('ornaments', $line);

# test operate_and_get_next
$INSTR = "one\cMtwo\cMthree\cM\cP\cP\cP\cO\cO\cO\cM";
$line = $t->readline("> ");	# one
$line = $t->readline("> ");	# two
$line = $t->readline("> ");	# three
$line = $t->readline("> ");
$res = $line eq 'one';	 ok('operate_and_get_next 1', $line);
$line = $t->readline("> ");
$res = $line eq 'two';	 ok('operate_and_get_next 2', $line);
$line = $t->readline("> ");
$res = $line eq 'three'; ok('operate_and_get_next 3', $line);
$line = $t->readline("> ");
$res = $line eq 'one';	 ok('operate_and_get_next 4', $line);

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

$INSTR = "!1\cM";
$line = $t->readline(prompt);
$res = $line eq 'abcdefgh'; ok('history 1', $line);

$INSTR = "123\cM";		# too short
$line = $t->readline(prompt);
$INSTR = "!!\cM";
$line = $t->readline(prompt);
$res = $line eq 'abcdefgh'; ok('history 2', $line);

$INSTR = "1234\cM";
$line = $t->readline(prompt);
$INSTR = "!!\cM";
$line = $t->readline(prompt);
$res = $line eq '1234'; ok('history 3', $line);

########################################################################
# test custom completion function

$t->parse_and_bind('set bell-style none'); # make readline quiet

$INSTR = "t/comp\cI\e*\cM";
$line = $t->readline("insert completion>");
# "a_b" < "README" on some kind of locale since strcoll() is used in
# the GNU Readline Library.
# Not all perl support setlocale.  My perl supports locale and I tried
#   use POSIX qw(locale_h); setlocale(LC_COLLATE, 'C');
# But it seems that it does not affect strcoll() linked to GNU
# Readline Library.
$res = $line eq 't/comptest/0123 t/comptest/012345 t/comptest/023456 t/comptest/README t/comptest/a_b '
    || $line eq 't/comptest/0123 t/comptest/012345 t/comptest/023456 t/comptest/a_b t/comptest/README ';
ok('insert completion', $line);

$INSTR = "t/comp\cIR\cI\cM";
$line = $t->readline("filename completion (default)>");
$res = $line eq 't/comptest/README '; ok('default completion', $line);

$a->{completion_entry_function} = $a->{'username_completion_function'};
$INSTR = "root\cI\cM";
$line = $t->readline("username completion>");
if ($line eq 'root ') {
    print "ok $n\tusername completion\n"; $n++;
} elsif ($line eq 'root') {
    print "ok $n\t# skipped.  It seems that there is a user whose name starts with 'root'\n"; $n++;
} else {
    print "not ok $n\tusername completion\n"; $n++;
    $ok = 0;
}

$a->{completion_word} = [qw(a list of words for completion and another word)];
$a->{completion_entry_function} = $a->{'list_completion_function'};
print $OUT "given list is: a list of words for completion and another word\n";
$INSTR = "a\cI\cIn\cI\cIo\cI\cM";
$line = $t->readline("list completion>");
$res = $line eq 'another '; ok('list completion', $line);


$a->{completion_entry_function} = $a->{'filename_completion_function'};
$INSTR = "t/comp\cI\cI\cI0\cI\cI1\cI\cI\cM";
$line = $t->readline("filename completion>");
$res = $line eq 't/comptest/0123'; ok('filename completion', $line);
undef $a->{completion_entry_function};

# attempted_completion_function

$a->{attempted_completion_function} = sub { undef; };
$a->{completion_entry_function} = sub {};
$INSTR = "t/comp\cI\cM";
$line = $t->readline("null completion 1>");
$res = $line eq 't/comp'; ok('null completion 1', $line);

$a->{attempted_completion_function} = sub { (undef, undef); };
undef $a->{completion_entry_function};
$INSTR = "t/comp\cI\cM";
$line = $t->readline("null completion 2>");
$res = $line eq 't/comptest/'; ok('null completion 2', $line);

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
$INSTR = "li\cIt/comp\cI\cI\cI0\cI\cI2\cI\cM";
$line = $t->readline("list & filename completion>");
$res = $line eq 'list t/comptest/023456 '; ok('list & file completion', $line);
undef $a->{attempted_completion_function};

# ignore_some_completions_function
$a->{ignore_some_completions_function} = sub {
    return (grep m|/$| || ! m|^(.*/)?[0-9]*$|, @_);
};
$INSTR = "t/co\cIRE\cI\cM";
$line = $t->readline("ignore_some_completion>");
$res = $line eq 't/comptest/README '; ok('ingore_some_completion', $line);
undef $a->{ignore_some_completions_function};

# char_is_quoted, filename_quoting_function, filename_dequoting_function

sub char_is_quoted ($$) {	# borrowed from bash-2.03:subst.c
    my ($string, $eindex) = @_;
    my ($i, $pass_next);

    for ($i = $pass_next = 0; $i <= $eindex; $i++) {
	my $c = substr($string, $i, 1);
	if ($pass_next) {
	    $pass_next = 0;
	    return 1 if ($i >= $eindex); # XXX was if (i >= eindex - 1)
	} elsif ($c eq '\'') {
	    $i = index($string, '\'', ++$i);
	    return 1 if ($i == -1 || $i >= $eindex);
#	} elsif ($c eq '"') {	# ignore double quote
	} elsif ($c eq '\\') {
	    $pass_next = 1;
	}
    }
    return 0;
}
$a->{char_is_quoted_p} = \&char_is_quoted;
$a->{filename_quoting_function} = sub {
    my ($text, $match_type, $quote_pointer) = @_;
    my $qc = $a->{filename_quote_characters};
    return $text if $quote_pointer;
    $text =~ s/[\Q${qc}\E]/\\$&/;
    return $text;
};
$a->{filename_dequoting_function} = sub {
    my ($text, $quote_char) = @_;
    $quote_char = chr $quote_char;
    $text =~ s/\\//g;
    return $text;
};

$a->{completer_quote_characters} = '\'';
$a->{filename_quote_characters} = ' _\'\\';

$INSTR = "t/comp\cIa\cI 't/comp\cIa\cI\cM";
$line = $t->readline("filename_quoting_function>");
$res = $line eq 't/comptest/a\\_b  \'t/comptest/a_b\' ';
ok('filename_quoting_function', $line);

$INSTR = "\'t/comp\cIa\\_\cI\cM";
$line = $t->readline("filename_dequoting_function>");
$res = $line eq '\'t/comptest/a_b\' ';
ok('filename_dequoting_function', $line);

undef $a->{char_is_quoted_p};
undef $a->{filename_quoting_function};
undef $a->{filename_dequoting_function};

# directory_completion_hook
$a->{directory_completion_hook} = sub {
    if ($_[0] eq 'comp/') {	# simple alias function
	$_[0] = 't/comptest/';
	return 1;
    } else {
	return 0;
    }
};

$INSTR = "comp/\cI\cM";
$line = $t->readline("directory_completion_hook>");
$res = $line eq 't/comptest/';
ok('directory_completion_hook', $line);
undef $a->{directory_completion_hook};

$t->parse_and_bind('set bell-style audible'); # resume to default style

########################################################################
# test rl_startup_hook, rl_pre_input_hook

$a->{startup_hook} = sub { $a->{point} = 10; };
$INSTR = "insert\cM";
$line = $t->readline("rl_startup_hook test>", "cursor is, <- here");
$res = $line eq 'cursor is,insert <- here'; ok('startup_hook', $line);
$a->{startup_hook} = undef;

$a->{pre_input_hook} = sub { $a->{point} = 10; };
$INSTR = "insert\cM";
$line = $t->readline("rl_pre_input_hook test>", "cursor is, <- here");
if ($version > 4.0 - 0.1) {
    $res = $line eq 'cursor is,insert <- here'; ok('pre_input_hook', $line);
} else {
    print "ok $n # skipped\n"; $n++;
}
$a->{pre_input_hook} = undef;

#########################################################################
# test redisplay_function
$a->{redisplay_function} = $a->{shadow_redisplay};
$INSTR = "\cX\cVThis is a password.\cM";
$line = $t->readline("password> ");
$res = $line eq 'This is a password.'; ok('redisplay_function', $line);
undef $a->{redisplay_function};

print "ok $n\n"; $n++;

#########################################################################
# test rl_display_match_list

if ($version > 4.0 - 0.1) {
    my @match_list = @{$a->{completion_word}};
    $t->display_match_list(\@match_list);
    $t->parse_and_bind('set print-completions-horizontally on');
    $t->display_match_list(\@match_list);
    $t->parse_and_bind('set print-completions-horizontally off');
    print "ok $n\n"; $n++;
} else {
    print "ok $n # skipped\n"; $n++;
}

#########################################################################
# test rl_completion_display_matches_hook

if ($version > 4.0 - 0.1) {
    # See 'eg/perlsh' for better example
    $a->{completion_display_matches_hook} = sub  {
	my($matches, $num_matches, $max_length) = @_;
	map { $_ = uc $_; }(@{$matches});
	$t->display_match_list($matches);
	$t->forced_update_display;
    };
    $t->parse_and_bind('set bell-style none'); # make readline quiet
    $INSTR = "Gnu.\cI\cI\cM";
    $t->readline("completion_display_matches_hook>");
    undef $a->{completion_display_matches_hook};
    print "ok $n\n"; $n++;
    $t->parse_and_bind('set bell-style audible'); # resume to default style
} else {
    print "ok $n # skipped\n"; $n++;
}

########################################################################
# test ornaments

$INSTR = "\cM\cM\cM\cM\cM\cM\cM";
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

print "ok $n\n"; $n++;

########################################################################
# end of non-interactive test
unless ($verbose) {
    # $^X : `perl' for dynamically linked perl, `./perl' for
    #        statically linked perl.
    print STDERR "ok\tTry \`$^X -Mblib t/readline.t verbose\', if you will.\n"
	if $ok;
    exit 0;
}
########################################################################
# interactive test

########################################################################
# test redisplay_function

$a->{redisplay_function} = $a->{shadow_redisplay};
$line = $t->readline("password> ");
print "<$line>\n";
undef $a->{redisplay_function};

########################################################################
# test rl_getc_function and rl_getc()

sub uppercase {
#    my $FILE = $a->{instream};
#    return ord uc chr $t->getc($FILE);
    return ord uc chr $t->getc($a->{instream});
}

$a->{getc_function} = \&uppercase;
print $OUT "\n" unless defined $t->readline("convert to uppercase>");
$a->{getc_function} = undef;

########################################################################
# test event_hook
$a->{getc_function} = undef;

my $timer = 20;			# 20 x 0.1 = 2.0 sec timer
$a->{event_hook} = sub {
    if ($timer-- < 0) {
	$a->{done} = 1;
	undef $a->{event_hook};
    }
};
$line = $t->readline("input in 2 seconds> ");
undef $a->{event_hook};
print "<$line>\n";

########################################################################
# convert control charactors to printable charactors (ex. "\cx" -> '\C-x')
sub toprint {
    join('',
	 map{$_ eq "\e" ? '\M-': ord($_)<32 ? '\C-'.lc(chr(ord($_)+64)) : $_}
	 (split('', $_[0])));
}

my %TYPE = (0 => 'Function', 1 => 'Keymap', 2 => 'Macro');

print $OUT "\n# Try the following commands.\n";
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

print $OUT "\n# history expansion test\n# quit by EOF (\\C-d)\n";
$a->{do_expand} = 1;
while (defined($line = $t->readline(prompt))) {
    print $OUT "<<$line>>\n";
}
print $OUT "\n";
