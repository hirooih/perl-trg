#
#	Gnu.pm --- The GNU Readline/History Library wrapper module
#
#	$Id: Gnu.pm,v 1.30 1997-01-21 17:04:33 hayashi Exp $
#
#	Copyright (c) 1996,1997 Hiroo Hayashi.  All rights reserved.
#
#	This program is free software; you can redistribute it and/or
#	modify it under the same terms as Perl itself.
#
#	Some of documentation strings in this file are cited from the
#	info of GNU Readline.

package Term::ReadLine::Gnu;

=head1 NAME

Term::ReadLine::Gnu - Perl extension for the GNU Readline/History Library

=head1 SYNOPSIS

  use Term::ReadLine;
  $term = new Term::ReadLine 'ProgramName';
  while ( defined ($_ = $term->readline('prompt>')) ) {
    ...
  }

=head1 DESCRIPTION

=head2 Overview

This is an implementation of Term::ReadLine using the GNU
Readline/History Library.

For basic functions object oriented interface is provided. These are
described in the section B<Methods>.

This package also has the interface with the almost all variables and
functions which are documented in the GNU Readline/History Library
Manual.  These variables and functions are documented in the section
B<Variables> and B<Functions> briefly.  For more detail of the GNU
Readline/History Library, see 'GNU Readline Library Manual' and 'GNU
History Library Manual'.

=head2 Methods

=cut

use strict;
use vars qw($VERSION @ISA %EXPORT_TAGS @EXPORT_OK);
use Carp;

$VERSION = '0.04';

require Exporter;
require DynaLoader;

@ISA = qw(Exporter DynaLoader);

#
#	Variable lists to be Export_OK
#
my @basefn = qw( rl_fetch_var		rl_store_var
		 rl_readline		add_history	history_expand
	         $rl_library_version	$rl_terminal_name
		 $rl_readline_name );

my @bindfn = qw( rl_add_defun		rl_make_bare_keymap	rl_copy_keymap
		 rl_make_keymap		rl_discard_keymap
		 rl_get_keymap		rl_set_keymap
		 rl_get_keymap_by_name	rl_get_keymap_name
		 rl_bind_key		rl_unbind_key
		 rl_generic_bind	rl_parse_and_bind
		 rl_read_init_file	rl_call_function
		 rl_named_function	rl_get_function_name
		 rl_function_of_keyseq	rl_invoking_keyseqs
		 rl_function_dumper	rl_list_funmap_names

		 $rl_executing_keymap	$rl_binding_keymap

		 ISFUNC			ISKMAP			ISMACR );

my @miscfn = qw( rl_begin_undo_group	rl_end_undo_group	rl_add_undo
		 free_undo_list		rl_do_undo		rl_modifying

		 UNDO_DELETE		UNDO_INSERT		UNDO_BEGIN
		 UNDO_END

		 rl_redisplay		rl_forced_update_display
		 rl_on_new_line		rl_reset_line_state	rl_message
		 rl_clear_message	rl_insert_text		rl_delete_text
		 rl_copy_text		rl_kill_text 

		 rl_read_key		rl_getc			rl_stuff_char
		 rl_initialize		rl_reset_terminal	ding

		 $rl_line_buffer	$rl_buffer_len
		 $rl_point		$rl_end			$rl_mark
		 $rl_done		$rl_pending_input	$rl_prompt
		 $rl_instream		$rl_outstream
		 $rl_startup_hook	$rl_event_hook
		 $rl_getc_function	$rl_redisplay_function
		 );

my @cbfn   = qw( rl_callback_handler_install
		 rl_callback_read_char
		 rl_callback_handler_remove );

my @cmplfn = qw( rl_complete_internal	completion_matches
		 filename_completion_function
		 username_completion_function
		 list_completion_function

		 $rl_completion_entry_function
		 $rl_attempted_completion_function
		 $rl_completion_query_items
		 $rl_basic_word_break_characters
		 $rl_basic_quote_characters
		 $rl_completer_word_break_characters
		 $rl_completer_quote_characters
		 $rl_filename_quote_characters
		 $rl_special_prefixes
		 $rl_completion_append_character
		 $rl_ignore_completion_duplicates
		 $rl_filename_completion_desired
		 $rl_filename_quoting_desired
		 $rl_inhibit_completion

		 NO_MATCH		SINGLE_MATCH		MULT_MATCH );

my @histfn = qw( using_history		remove_history
		 replace_history_entry	clear_history		stifle_history
		 history_is_stifled	where_history		current_history
		 history_get		history_total_bytes

		 history_set_pos	previous_history	next_history

		 history_search		history_search_prefix

		 read_history_range	write_history		append_history
		 history_trancate_file

		 $history_no_expand_chars
		 $history_search_delimiter_chars
		 $history_base
		 $history_length
		 $history_expansion_char
		 $history_subst_char
		 $history_comment_char
		 $history_quotes_inhibit_expansion );

%EXPORT_TAGS = (
		base_function		=> \@basefn,

		keybind_function	=> \@bindfn,
		misc_function		=> \@miscfn,
		callback_function	=> \@cbfn,
		completion_function	=> \@cmplfn,
		history_function	=> \@histfn,
		all			=> [ @basefn, @bindfn, @miscfn,
					     @cbfn, @cmplfn, @histfn ]
	       );

Exporter::export_ok_tags(qw(base_function	keybind_function
			    misc_function	callback_function
			    completion_function	history_function));

bootstrap Term::ReadLine::Gnu $VERSION;

# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.

=over 4

=item C<ReadLine>

returns the actual package that executes the commands. If you have
installed this package,  possible value is C<Term::ReadLine::Gnu>.

=cut

sub ReadLine { 'Term::ReadLine::Gnu'; }

=item C<new(NAME,[IN[,OUT]])>

returns the handle for subsequent calls to following functions.
Argument is the name of the application.  Optionally can be followed
by two arguments for C<IN> and C<OUT> file handles. These arguments
should be globs.

=cut

my @Completion_Word_List;	# used by list_completion_function()
my $Operate_Index;
my $Next_Operate_Index;

# The origin of this function is Term::ReadLine::Perl.pm by Ilya Zakharevich.
sub new {
    my $this = shift;		# Package
    my $class = ref($this) || $this;

    my $name = shift;
    rl_store_var('rl_readline_name', $name);

    if (!@_) {
	my ($IN,$OUT) = Term::ReadLine::Stub::findConsole();
	open(IN,"<$IN")   || croak "Cannot open $IN for read";
	open(OUT,">$OUT") || croak "Cannot open $OUT for write";
	rl_store_var('rl_instream', \*IN);
	rl_store_var('rl_outstream', \*OUT);
    } else {
	rl_store_var('rl_instream', shift);
	rl_store_var('rl_outstream', shift);
    }
    $Operate_Index = $Next_Operate_Index = undef; # for F_OperateAndGetNext()

    # The following is here since it is mostly used for perl input:
#    $rl_basic_word_break_characters .= '-:+/*,[])}';

    my $self = {
		AppName		=> $name,
		MinLength	=> 1,
		DoExpand	=> 0,
		MaxHist		=> undef,
		CompletionWordList	=> \@Completion_Word_List,
	       };
    bless $self, $class;
    $self;
}

=item C<readline(PROMPT[,PREPUT])>

gets an input line, with actual C<GNU Readline> support.  Trailing
newline is removed.  Returns C<undef> on C<EOF>.  C<PREPUT> is an
optional argument meaning the initial value of input.

The optional argument C<PREPUT> is granted only if the value C<preput>
is in C<Features>.

=cut

use vars qw($_Preput);

sub readline {			# should be ReadLine
    my $self = shift;
    my ($prompt, $preput) = @_;

    # cf. F_OperateAndGetNext()
    if (defined $Operate_Index) {
	$Next_Operate_Index = $Operate_Index + 1;
	my $next_line = history_get($Next_Operate_Index);
	$preput = $next_line if defined $next_line;
	undef $Operate_Index;
    }

    # call readline()
    my $line;
    if (defined $preput) {
	$_Preput = $preput;
	rl_store_var('rl_startup_hook', sub { rl_insert_text($_Preput) });
	$line = rl_readline($prompt);
	rl_store_var('rl_startup_hook', undef);
    } else {
	$line = rl_readline($prompt);
    }
    undef $Next_Operate_Index;
    return undef unless defined $line;

    # history expansion
    if ($self->{DoExpand}) {
	my $result;
	($result, $line) = history_expand($line);
	my $outstream = rl_fetch_var('rl_outstream');
	print $outstream "$line\n" if ($result);
     
	# return without adding line into history
	if ($result < 0 || $result == 2) {
	    return '';		# don't return `undef' which means EOF.
	}
    }

    # add to history buffer
    $self->addhistory($line)
	if (length($line) >= $self->{MinLength});

    return $line;
}

=item C<addhistory(LINE1, LINE2, ...)>

adds the lines to the history of input, from where it can be used if
the actual C<readline> is present.

=cut

sub addhistory {		# Why not AddHistory ?
    shift;
    local($_);
    foreach (@_) {
	add_history($_);
    }
}

=item C<StifleHistory(MAX)>

stifles the history list, remembering only the last C<MAX> entries.
If MAX is undef,  remembers all entries.

=cut

sub StifleHistory {
    my $self = shift;
    stifle_history($self->{MaxHist} = shift);
}

=item C<SetHistory(LINE1, LINE2, ...)>

sets the history of input, from where it can be used if the actual
C<readline> is present.

=cut

sub SetHistory {
    shift;
    local($_);
    clear_history();
    foreach (@_) {
	add_history($_);
    }
}

=item C<GetHistory>

returns the history of input as a list, if actual C<readline> is present.

=cut

sub GetHistory {
#    _rl_GetHistory();
    my ($i, $history_base, $history_length, @d);
    $history_base   = rl_fetch_var('history_base');
    $history_length = rl_fetch_var('history_length');
    for ($i = $history_base; $i < $history_base + $history_length; $i++) {
	push(@d, history_get($i));
    }
    @d;
}

=item C<ReadHistory(FILENAME [,FROM [,TO]])>

adds the contents of C<FILENAME> to the history list, a line at a
time.  If C<FILENAME> is false, then read from F<~/.history>.  Start
reading at line C<FROM> and end at C<TO>.  If C<FROM> is omitted or
zero, start at the beginning.  If C<TO> is omittied or less than
C<FROM>, then read until the end of the file.  Returns true if
successful, or false if not.

=cut

sub ReadHistory {
    shift;
    ! read_history_range(@_);
}

=item C<WriteHistory(FILENAME)>

writes the current history to C<FILENAME>, overwriting C<FILENAME> if
necessary.  If C<FILENAME> is false, then write the history list to
F<~/.history>.  Returns true if successful, or false if not.

=cut

sub WriteHistory {
    shift;
    ! write_history($_[0]);
}

=item C<MinLine([MAX])>

If argument C<MAX> is specified, it is an advice on minimal size of
line to be included into history.  C<undef> means do not include
anything into history.  Returns the old value.

=cut

sub MinLine {
    my $self = shift;
    my $old_minlength = $self->{MinLength};
    $self->{MinLength} = shift;
    $old_minlength;
}

=item C<AddDefun(NAME, FUNC [,KEY])>

Add name to the Perl function FUNC.  If optional argument KEY is
specified, bind it to the FUNC.  Returns non-zero in the case of an
invalid KEY.

  Example:
	# name name `reverse-line' to a function reverse_line(), and bind
	# it to "\C-t"
	$term->AddDefun('reverse-line', \&reverse_line, "\ct");

=cut

sub AddDefun {
    my $self = shift;
    &rl_add_defun;
}

=item C<BindKey(KEY, FUNCTION [,MAP])>

Bind KEY to the FUNCTION.  FUNCTION is the name added by the
C<AddDefun> method.  If optional argument MAP is specified, binds
in MAP.  Returns non-zero in case of error.

=cut

sub BindKey {
    my $self = shift;
    &rl_bind_key;
}

=item C<UnbindKey(KEY [,MAP])>

Bind KEY to the null function.  Returns non-zero in case of error.

=cut

sub UnbindKey {
    my $self = shift;
    &rl_unbind_key;
}

=item C<ParseAndBind(LINE)>

Parse LINE as if it had been read from the F<~/.inputrc> file and
perform any key bindings and variable assignments found.  For more
detail see 'GNU Readline Library Manual'.

=cut

sub ParseAndBind {
    my $self = shift;
    &rl_parse_and_bind;
}

# The following functions are defined in ReadLine.pm.

=item C<IN>, C<OUT>

return the file handles for input and output or C<undef> if
C<readline> input and output cannot be used for Perl.

=cut

sub IN  { rl_fetch_var('rl_instream'); }
sub OUT { rl_fetch_var('rl_outstream'); }

=item C<findConsole>

returns an array with two strings that give most appropriate names for
files for input and output using conventions C<"E<lt>$in">, C<"E<gt>$out">.

=item C<Features>

Returns a reference to a hash with keys being features present in
current implementation. Several optional features are used in the
minimal interface: C<appname> should be present if the first argument
to C<new> is recognized, and C<minline> should be present if
C<MinLine> method is not dummy.  C<autohistory> should be present if
lines are put into history automatically (maybe subject to
C<MinLine>), and C<addhistory> if C<addhistory> method is not dummy. 
C<preput> means the second argument to C<readline> method is processed.
C<getHistory> and C<setHistory> denote that the corresponding methods are 
present. C<tkRunning> denotes that a Tk application may run while ReadLine
is getting input B<(undocumented feature)>.

=cut

my %Features = (appname => 1, minline => 1, autohistory => 1,
		preput => 1, do_expand => 1, stifleHistory => 1,
		getHistory => 1, setHistory => 1, addHistory => 1,
		readHistory => 1, writeHistory => 1, parseAndBind => 1,
		customCompletion => 1, tkRunning => 0);

sub Features { \%Features; }

#
#	Readline/History Library Variable Access Routines
#

=item C<FetchVar(VARIABLE_NAME), StoreVar(VARIABLE_NAME, VALUE)>

Fetch and store a value of a GNU Readline Library variable.  See
section VARIABLES.

=cut

my %_rl_vars
    = (
       rl_line_buffer				=> ['S', 0],
       rl_prompt				=> ['S', 1],
       rl_library_version			=> ['S', 2],
       rl_terminal_name				=> ['S', 3],
       rl_readline_name				=> ['S', 4],
       rl_basic_word_break_characters		=> ['S', 5],
       rl_basic_quote_characters		=> ['S', 6],
       rl_completer_word_break_characters	=> ['S', 7],
       rl_completer_quote_characters		=> ['S', 8],
       rl_filename_quote_characters		=> ['S', 9],
       rl_special_prefixes			=> ['S', 10],
       history_no_expand_chars			=> ['S', 11],
       history_search_delimiter_chars		=> ['S', 12],
       
       rl_point					=> ['I', 0],
       rl_end					=> ['I', 1],
       rl_mark					=> ['I', 2],
       rl_done					=> ['I', 3],
       rl_pending_input				=> ['I', 4],
       rl_completion_query_items		=> ['I', 5],
       rl_completion_append_character		=> ['C', 6],
       rl_ignore_completion_duplicates		=> ['I', 7],
       rl_filename_completion_desired		=> ['I', 8],
       rl_filename_quoting_desired		=> ['I', 9],
       rl_inhibit_completion			=> ['I', 10],
       history_base				=> ['I', 11],
       history_length				=> ['I', 12],
       history_expansion_char			=> ['C', 13],
       history_subst_char			=> ['C', 14],
       history_comment_char			=> ['C', 15],
       history_quotes_inhibit_expansion		=> ['I', 16],

       rl_startup_hook				=> ['F', 0],
       rl_event_hook				=> ['F', 1],
       rl_getc_function				=> ['F', 2],
       rl_redisplay_function			=> ['F', 3],
       rl_completion_entry_function		=> ['F', 4],
       rl_attempted_completion_function		=> ['F', 5],

       rl_instream				=> ['IO', 0],
       rl_outstream				=> ['IO', 1],

       rl_executing_keymap			=> ['K', 0],
       rl_binding_keymap			=> ['K', 1],
      );

sub FetchVar {
    my $self = shift;
    rl_fetch_var(@_);
}

sub rl_fetch_var ( $ ) {
    my $name = shift;
    if (! defined $_rl_vars{$name}) {
	carp "Term::ReadLine::Gnu::FetchVar: Unknown variable name `$name'\n";
	return undef ;
    }
    
    my ($type, $id) = @{$_rl_vars{$name}};
    if ($type eq 'S') {
	return _rl_fetch_str($id);
    } elsif ($type eq 'I') {
	return _rl_fetch_int($id);
    } elsif ($type eq 'C') {
	return chr(_rl_fetch_int($id));
    } elsif ($type eq 'F') {
	return _rl_fetch_function($id);
    } elsif ($type eq 'IO') {
	return _rl_fetch_iostream($id);
    } elsif ($type eq 'K') {
	return _rl_fetch_keymap($id);
    } else {
	carp "Term::ReadLine::Gnu::FetchVar: Illegal type `$type'\n";
	return undef;
    }
}

sub StoreVar {
    my $self = shift;
    rl_store_var(@_);
}

sub rl_store_var ( $$ ) {
    my $name = shift;
    if (! defined $_rl_vars{$name}) {
	carp "Term::ReadLine::Gnu::StoreVar: Unknown variable name `$name'\n";
	return undef ;
    }
    
    my $value = shift;
    my ($type, $id) = @{$_rl_vars{$name}};
    if ($type eq 'S') {
	if ($name eq 'rl_line_buffer') {
	    # If you modify rl_line_buffer directly, you must manage
	    # rl_line_buffer_len.
	    &rl_begin_undo_group;
	    &rl_delete_text();
	    rl_store_var('rl_point', 0); # rl_delete_text() does not
                                         # care rl_point ;-<
	    rl_insert_text($value);
	    &rl_end_undo_group;
	    return $value;
	}
	return _rl_store_str($value, $id);
    } elsif ($type eq 'I') {
	return _rl_store_int($value, $id);
    } elsif ($type eq 'C') {
	return chr(_rl_store_int(ord($value), $id));
    } elsif ($type eq 'F') {
	return _rl_store_function($value, $id);
    } elsif ($type eq 'IO') {
	return _rl_store_iostream($value, $id);
    } elsif ($type eq 'K') {
	carp "Term::ReadLine::Gnu::StoreVar: read only variable `$name'\n";
	return undef;
    } else {
	carp "Term::ReadLine::Gnu::StoreVar: Illegal type `$type'\n";
	return undef;
    }
}

#
#	Tie functions for Readline/History Library variables
#
package Term::ReadLine::Gnu::Var;
use Carp;
use strict;

sub TIESCALAR {
    my $class = shift;
    my $name = shift;
    return bless \$name, $class;
}

sub FETCH {
    my $self = shift;
    confess "wrong type" unless ref $self;
    return Term::ReadLine::Gnu::rl_fetch_var($$self);
}

sub STORE {
    my $self = shift;
    confess "wrong type" unless ref $self;
    return Term::ReadLine::Gnu::rl_store_var($$self, shift);
}

package Term::ReadLine::Gnu;

#	Tie all Readline/History variables
foreach (keys %_rl_vars) {
    eval "use vars '\$$_'; tie \$$_, 'Term::ReadLine::Gnu::Var', '$_';";
}

#
#	GNU Readline/History Library constant definition
#
# for rl_filename_quoting_function
sub NO_MATCH	 { 0; }
sub SINGLE_MATCH { 1; }
sub MULT_MATCH   { 2; }

# for rl_generic_bind, rl_function_of_keyseq
sub ISFUNC	{ 0; }
sub ISKMAP	{ 1; }
sub ISMACR	{ 2; }

# for rl_add_undo
sub UNDO_DELETE	{ 0; }
sub UNDO_INSERT	{ 1; }
sub UNDO_BEGIN	{ 2; }
sub UNDO_END	{ 3; }

#
#	Readline function wrappers
#
sub _str2map ( $ ) {
    return ref $_[0] ? $_[0]
	: (rl_get_keymap_by_name($_[0]) || carp "unknown keymap name \`$_[0]\'\n");
}

sub _str2fn ( $ ) {
    return ref $_[0] ? $_[0]
	: (rl_named_function($_[0]) || carp "unknown function name \`$_[0]\'\n");
}

sub rl_copy_keymap ( $ )    { return _rl_copy_keymap(_str2map($_[0])); }
sub rl_discard_keymap ( $ ) { return _rl_discard_keymap(_str2map($_[0])); }
sub rl_set_keymap ( $ )     { return _rl_set_keymap(_str2map($_[0])); }

sub rl_bind_key ( $$;$ ) {
    if (defined $_[2]) {
	return _rl_bind_key($_[0], _str2fn($_[1]), _str2map($_[2]));
    } else {
	return _rl_bind_key($_[0], _str2fn($_[1]));
    }
}

sub rl_unbind_key ( $;$ ) {
    if (defined $_[1]) {
	return _rl_unbind_key($_[0], _str2map($_[1]));
    } else {
	return _rl_unbind_key($_[0]);
    }
}

sub rl_generic_bind ( $$$;$ ) {
    if      ($_[0] == ISFUNC) {
	if (defined $_[3]) {
	    _rl_generic_bind_function($_[1], _str2fn($_[2]), _str2map($_[3]));
	} else {
	    _rl_generic_bind_function($_[1], _str2fn($_[2]));
	}
    } elsif ($_[0] == ISKMAP) {
	if (defined $_[3]) {
	    _rl_generic_bind_keymap($_[1], _str2map($_[2]), _str2map($_[3]));
	} else {
	    _rl_generic_bind_keymap($_[1], _str2map($_[2]));
	}
    } elsif ($_[0] == ISMACR) {
	if (defined $_[3]) {
	    _rl_generic_bind_macro($_[1], $_[2], _str2map($_[3]));
	} else {
	    _rl_generic_bind_macro($_[1], $_[2]);
	}
    } else {
	carp("Term::ReadLine::Gnu::rl_generic_bind: invalid \`type\'\n");
    }
}
	    
sub rl_call_function ( $;$$ ) {
    if (defined $_[2]) {
	return _rl_call_function(_str2fn($_[0]), $_[1], $_[2]);
    } elsif (defined $_[1]) {
	return _rl_call_function(_str2fn($_[0]), $_[1]);
    } else {
	return _rl_call_function(_str2fn($_[0]));
    }
}

sub rl_invoking_keyseqs ( $;$ ) {
    if (defined $_[1]) {
	return _rl_invoking_keyseqs(_str2fn($_[0]), _str2map($_[1]));
    } else {
	return _rl_invoking_keyseqs(_str2fn($_[0]));
    }
}

sub rl_message {
    my $fmt = shift;
    my $line = sprintf($fmt, @_);
    _rl_message($line);
}

#
#	List Completion Function
#

BEGIN {
    my $i;

    sub list_completion_function ( $$ ) {
	my($text, $state) = @_;
	my $entry;

	$i = $state ? $i + 1 : 0; # clear counter at the first call
	for (; $i <= $#Completion_Word_List; $i++) {
	    return $entry
		if (($entry = $Completion_Word_List[$i]) =~ /^$text/);
	}
	return undef;
    }
}

#
#	a sample custom function
#	defined in this module for the compatibility with Term::ReadLine::Perl
#
sub operate_and_get_next {
    ## Operate - accept the current line and fetch from the
    ## history the next line relative to current line for default.
    my ($count, $key) = @_;

    if (defined $Next_Operate_Index) {
	history_set_pos($Next_Operate_Index - rl_fetch_var('history_base'));
	undef $Next_Operate_Index;
    }
    rl_call_function("accept-line", $count, $key);

    $Operate_Index = rl_fetch_var('history_base') + where_history();
}

rl_add_defun('operate-and-get-next', \&operate_and_get_next, ord "\co");

1;
__END__

=back

=head2 Variables

Following GNU Readline Library variables can be accessed from Perl
program.  See 'GNU Readline Library Manual' and ' GNU History Library
Manual' for each variable.

You can access them with FetchVar()/StoreVar() methods and
rl_fetch_var()/rl_store_var() functions.  And all these variables are
tied to Perl scalar variables.  These are not exported by default.
Full qualified name or explicit "import" is required.

Examples:

    # using method
    $v = $term->FetchVar('rl_library_version');
    # using full qualified name
    $v = Term::ReadLine::GNU::rl_fetch_var('rl_library_version');
    $v = $Term::ReadLine::GNU::rl_library_version;
    # import symbols
    use Term::ReadLine::GNU qw(rl_fetch_var rl_library_version);
    $v = rl_fetch_var('rl_library_version');
    $v = $rl_library_version;

=over 4

=item base_function

	rl_library_version (read only)
	rl_terminal_name
	rl_readline_name

=item keybind_function

	rl_executing_keymap (read only)
	rl_binding_keymap (read only)

=item misc_function

	rl_line_buffer
	rl_point
	rl_end
	rl_mark
	rl_done		
	rl_pending_input
	rl_prompt
	rl_instream
	rl_outstream
	rl_startup_hook
	rl_event_hook
	rl_getc_function
	rl_redisplay_function

=item completion_function

	rl_completion_entry_function
	rl_attempted_completion_function
	rl_completion_query_items
	rl_basic_word_break_characters
	rl_basic_quote_characters
	rl_completer_word_break_characters
	rl_completer_quote_characters
	rl_filename_quote_characters
	rl_special_prefixes
	rl_completion_append_character
	rl_ignore_completion_duplicates
	rl_filename_completion_desired
	rl_filename_quoting_desired
	rl_inhibit_completion

=item history_function

	history_no_expand_chars
	history_search_delimiter_chars
	history_base
	history_length
	history_expansion_char
	history_subst_char
	history_comment_char
	history_quotes_inhibit_expansion

=back

=head2 Functions

Followings GNU Readline/History Library support functions are provided
as Perl functions.  These are not exported by default.  Full qualified
name or explicit "import" is required.

Examples:

    # using full qualified name
    $v = Term::ReadLine::GNU::rl_fetch_var('rl_library_version');
    # import symbols
    use Term::ReadLine::GNU qw(rl_fetch_var);
    $v = rl_fetch_var('rl_library_version');

=over 4

=item base_function

	rl_fetch_var(name)
	rl_store_var(name, val)
	rl_readline([prompt])
	add_history(string)
	history_expand(line)

=item keybind_function

	rl_add_defun(name, perl_fn [,key])
	rl_make_bare_keymap()
	rl_copy_keymap(map)
	rl_make_keymap()
	rl_discard_keymap(map)
	rl_get_keymap()
	rl_set_keymap(map)
	rl_get_keymap_by_name(name)
	rl_get_keymap_name(map)
	rl_bind_key(key [,function [,map]])
	rl_unbind_key(key [,map])
	rl_generic_bind(type, keyseq, data [,map])
	rl_parse_and_bind(line)
	rl_read_init_file([filename])
	rl_call_function(function [,count [,key]])
	rl_named_function(name)
	rl_get_function_name(function)
	rl_function_of_keyseq(keyseq [,map])
	rl_invoking_keyseqs(function [,map])
	rl_function_dumper([readable])
	rl_list_funmap_names()

=item misc_function

	rl_begin_undo_group()
	rl_end_undo_group()
	rl_add_undo(what, start, end, text)
	free_undo_list()
	rl_do_undo()
	rl_modifying([start [,end]])
	rl_redisplay()
	rl_forced_update_display()
	rl_on_new_line()
	rl_reset_line_state()
	rl_message(text)
	rl_clear_message()
	rl_insert_text(text)
	rl_delete_text([start [,end]])
	rl_copy_text([start [,end]])
	rl_kill_text ([start [,end]])
	rl_read_key()
	rl_stuff_char(c)
	rl_initialize()
	rl_reset_terminal([terminal_name])
	ding()

=item callback_function

	rl_callback_handler_install(prompt, lhandler)
	rl_callback_read_char()
	rl_callback_handler_remove()

=item completion_function

	rl_complete_internal([what_to_do])
	completion_matches(text [,fn])
	filename_completion_function(text, state)
	username_completion_function(text, state)
	list_completion_function(text, state)

=item history_function

	using_history()
	remove_history(which)
	replace_history_entry(which, line [,data])
	clear_history()
	stifle_history(i)
	history_is_stifled()
	where_history()
	current_history()
	history_get(offset)
	history_total_bytes()
	history_set_pos(pos)
	previous_history()
	next_history()
	history_search(string [,direction [,pos]])
	history_search_prefix(string [,direction])
	read_history_range([filename [,from [,to]]])
	write_history([filename])
	append_history(nelements [,filename])
	history_trancate_file([filename [,nlines]])

=back

=head2 Custom Completion

In this section variables and functions for custom completion is
described with examples.

Most of descriptions in this section is cited from GNU Readline
Library manual.

=over 4

=item C<rl_completion_entry_function>

This variable holds reference refers to a generator function for
C<completion_matches()>.

A generator function is called repeatedly from
C<completion_matches()>, returning a string each time.  The arguments
to the generator function are TEXT and STATE.  TEXT is the partial
word to be completed.  STATE is zero the first time the function is
called, allowing the generator to perform any necessary
initialization, and a positive non-zero integer for each subsequent
call.  When the generator function returns C<undef> this signals
C<completion_matches()> that there are no more possibilities left.

If the value is undef, built-in C<filename_completion_function> is
used.

A sample generator function, C<list_completion_function>, is defined
in Gnu.pm.  You can use it as follows;

    use Term::ReadLine;
    use Term::ReadLine::Gnu qw(:completion_function);
    ...
    my $term = new Term::ReadLine 'sample';
    ...
    $rl_completion_entry_function = \&list_completion_function;
    ...
    @{$term->{CompletionWordList}} =
	qw(list of words which you want to use for completion);
    $term->readline("custom completion>");

See also C<completion_matches>.

=item C<rl_attempted_completion_function>

A reference to an alternative function to create matches.

The function is called with TEXT, LINE_BUFFER, START, and END.
LINE_BUFFER is a current input buffer string.  START and END are
indices in LINE_BUFFER saying what the boundaries of TEXT are.

If this function exists and returns null list or C<undef>, or if this
variable is set to C<undef>, then an internal function
C<rl_complete()> will call the value of
C<$rl_completion_entry_function> to generate matches, otherwise the
array of strings returned will be used.

The default value of this variable is C<undef>.  You can use it as follows;

    use Term::ReadLine::Gnu qw(:completion_function);
    sub sample_completion {
        my ($text, $line, $start, $end) = @_;
        # If first word then username completion, else filename completion
        if (substr($line, 0, $start) =~ /^\s*$/) {
    	    return completion_matches($text, \&username_completion_function);
        } else {
    	    return ();
        }
    }
    ...
    $rl_attempted_completion_function = \&sample_completion;

=item C<completion_matches(TEXT, ENTRY_FUNC)>

Returns an array of strings which is a list of completions for TEXT.
If there are no completions, returns C<undef>.  The first entry
in the returned array is the substitution for TEXT.  The remaining
entries are the possible completions.

ENTRY_FUNC is a generator function which has two args, and returns a
string.  The first argument is TEXT.  The second is a state argument;
it is zero on the first call, and non-zero on subsequent calls.
ENTRY_FUNC returns a C<undef> to the caller when there are no more
matches.

If the value of ENTRY_FUNC is undef, built-in
C<filename_completion_function> is used.

C<completion_matches> is a Perl wrapper function of an internal
function C<completion_matches()>.  See also
C<$rl_completion_entry_function>.

=item C<list_completion_function(TEXT, STATE)>

A sample generator function defined by Term::ReadLine::Gnu.pm.
Example code at C<rl_completion_entry_function> shows how to use this
function.

=back

=head1 FILES

=over 4

=item F<~/.inputrc>

Readline init file.  Using this file it is possible that you would
like to use a different set of key bindings.  When a program which
uses the Readline library starts up, the init file is read, and the
key bindings are set.

Conditional key binding is also available.  The program name which is
specified by the first argument of C<new> method is used as the
application construct.

For example, when your program call C<new> method like this;

	...
	$term = new Term::ReadLine 'PerlSh';
	...

your F<~/.inputrc> can define key bindings only for it as follows;

	...
	$if PerlSh
	Meta-Rubout: backward-kill-word
	"\C-x\C-r": re-read-init-file
        "\e[11~": "Function Key 1"
	$endif
	...

=back

=head1 EXPORTS

None.

=head1 SEE ALSO

GNU Readline Library Manual

GNU History Library Manual

Term::ReadLine

Term::ReadLine::Perl (Term-ReadLine-xx.tar.gz)

perl(1).

=head1 AUTHOR

Hiroo Hayashi, hayashi@pdcd.ilab.toshiba.co.jp

=head1 TODO

support TkRunning

=head1 BUGS

rl_add_defun() can define up to 16 functions.

rl_message() does not work.

Some other functions are not tested yet.

=cut
