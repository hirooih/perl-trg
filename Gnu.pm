#
#	Gnu.pm --- The GNU Readline/History Library wrapper module
#
#	$Id: Gnu.pm,v 1.15 1996-12-29 13:49:31 hayashi Exp $
#
#	Copyright (c) 1996 Hiroo Hayashi.  All rights reserved.
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

This is an implementation of Term::ReadLine using the GNU
Readline/History Library.

For more detail of the GNU Readline/History Library, see 'GNU
Readline Library Manual' and 'GNU History Library Manual'.

=cut

use strict;
#use vars qw($VERSION @ISA %EXPORT_TAGS @EXPORT_OK);
use vars qw($VERSION @ISA);
use Carp;

require Exporter;
require DynaLoader;

@ISA = qw(Exporter DynaLoader);
$VERSION = '0.04';

#%EXPORT_TAGS = (custom_completion => [qw(completion_matches
#					 list_completion_functon)]);
#Exporter::export_ok_tags('custom_completion');

bootstrap Term::ReadLine::Gnu $VERSION;

# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.

=over 4

=item C<ReadLine>

returns the actual package that executes the commands. If you have
installed this package,  possible value is C<Term::ReadLine::Gnu>.

=cut

sub ReadLine { 'Term::ReadLine::Gnu'; }

=item C<new(NAME,[IN[,OUT]]>

returns the handle for subsequent calls to following functions.
Argument is the name of the application.  Optionally can be followed
by two arguments for C<IN> and C<OUT> filehandles. These arguments
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

    my ($instream, $outstream);
    if (!@_) {
	my ($IN,$OUT) = Term::ReadLine::Stub::findConsole(); # !!!
	open(IN,"<$IN")   || croak "Cannot open $IN for read";
	open(OUT,">$OUT") || croak "Cannot open $OUT for write";
	_rl_set_instream (fileno($instream  = \*IN));
	_rl_set_outstream(fileno($outstream = \*OUT));
    } else {
	_rl_set_instream (fileno($instream  = shift));
	_rl_set_outstream(fileno($outstream = shift));
    }
    $Operate_Index = $Next_Operate_Index = undef; # for F_OperateAndGetNext()
    # The following is here since it is mostly used for perl input:
#    $rl_basic_word_break_characters .= '-:+/*,[])}';

    my $self = {
		IN		=> $instream,
		OUT		=> $outstream,
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

gets an input line, with actual C<GNU readline> support.  Trailing
newline is removed.  Returns C<undef> on C<EOF>.  C<PREPUT> is an
optional argument meaning the initial value of input.

The optional argument C<PREPUT> is granted only if the value C<preput>
is in C<Features>.

=cut

sub readline {
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
    $preput = defined $preput ? $preput : '';
    my $line = _rl_readline($prompt, $preput);
    undef $Next_Operate_Index;
    return undef unless defined $line;

    # history expansion
    if ($self->{DoExpand}) {
	my $result;
	($result, $line) = history_expand($line);
	my $outstream = $self->{OUT};
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
    add_history(@_);
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
    _rl_SetHistory(@_);
}

=item C<GetHistory>

returns the history of input as a list, if actual C<readline> is present.

=cut

sub GetHistory {
    _rl_GetHistory();
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

=item C<ParseAndBind(LINE)>

Parse LINE as if it had been read from the F<~/.inputrc> file and
perform any key bindings and variable assignments found.  For more
detail see 'GNU Readline Library Manual'.

=cut

sub ParseAndBind {
    my $self = shift;
    rl_parse_and_bind(shift);
}

=item C<BindKey(FUNC, KEY, NAME)>

Binds KEY to perl function FUNC.  Optional argument NAME is a name of
the function.  Returns non-zero in the case of an invalid KEY.

  Example:
	# bind function reverse_line() to "\C-t"
	$term->BindKey(\&reverse_line, "\ct", 'reverse-line');

=cut

sub BindKey {
    my $self = shift;
    my ($func, $key, $name) = @_;
    rl_add_defun($func, ord $key, $name);
}

=item C<UnbindKey(KEY)>

Bind KEY to the null function.  Returns non-zero in case of error.

=cut

sub UnbindKey {
    my $self = shift;
    my ($key) = @_;
    rl_unbind_key(ord $key);
}

#
#	a sample custom function
#	defined in this module for compatibility with Term::ReadLine::Perl
#
sub operate_and_get_next {
    ## Operate - accept the current line and fetch from the
    ## history the next line relative to current line for default.
    my ($count, $key) = @_;

    if (defined $Next_Operate_Index) {
	history_set_pos($Next_Operate_Index - rl_fetch_var('history_base'));
	undef $Next_Operate_Index;
    }
    rl_do_named_function("accept-line", $count, $key);

    $Operate_Index = rl_fetch_var('history_base') + where_history();
}

=item C<FetchVar(VARIABLE_NAME), StoreVar(VARIABLE_NAME)>

Fetch and store a value of a GNU Readline Library variable.  See
section VARIABLES.

=cut

my %_rl_vars
    = (
       rl_line_buffer				=> ['S', 0],
       rl_library_version			=> ['S', 1],
       rl_readline_name				=> ['S', 2],
       rl_basic_word_break_characters		=> ['S', 3],
       rl_basic_quote_characters		=> ['S', 4],
       rl_completer_word_break_characters	=> ['S', 5],
       rl_completer_quote_characters		=> ['S', 6],
       rl_filename_quote_characters		=> ['S', 7],
       rl_special_prefixes			=> ['S', 8],
       history_no_expand_chars			=> ['S', 9],
       history_search_delimiter_chars		=> ['S', 10],
       
       rl_line_buffer_len			=> ['I', 0],
       rl_point					=> ['I', 1],
       rl_end					=> ['I', 2],
       rl_mark					=> ['I', 3],
       rl_done					=> ['I', 4],
       rl_pending_input				=> ['I', 5],
       rl_completion_query_items		=> ['I', 6],
       rl_completion_append_character		=> ['C', 7],
       rl_ignore_completion_duplicates		=> ['I', 8],
       rl_filename_completion_desired		=> ['I', 9],
       rl_filename_quoting_desired		=> ['I', 10],
       rl_inhibit_completion			=> ['I', 11],
       history_base				=> ['I', 12],
       history_length				=> ['I', 13],
       history_offset				=> ['I', 14],
       history_expansion_char			=> ['C', 15],
       history_subst_char			=> ['C', 16],
       history_comment_char			=> ['C', 17],
       history_quotes_inhibit_expansion		=> ['I', 18],
#         history_expansion_char			=> ['C', 14],
#         history_subst_char			=> ['C', 15],
#         history_comment_char			=> ['C', 16],
#         history_quotes_inhibit_expansion		=> ['I', 17],

       rl_completion_entry_function		=> ['F', 'filename'],
       rl_attempted_completion_function		=> ['F', undef],
      );

sub FetchVar {
    my $self = shift;
    rl_fetch_var(@_);
}

sub rl_fetch_var ($) {
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
	my $func = $id;
	return $func;		# return value which saved in perl variable
    } else {
	carp "Term::ReadLine::Gnu::FetchVar: Illegal type `$type'\n";
	return undef;
    }
}

sub StoreVar {
    my $self = shift;
    rl_store_var(@_);
}

sub rl_store_var ($$) {
    my $name = shift;
    if (! defined $_rl_vars{$name}) {
	carp "Term::ReadLine::Gnu::StoreVar: Unknown variable name `$name'\n";
	return undef ;
    }
    
    my $value = shift;
    my ($type, $id) = @{$_rl_vars{$name}};
    if ($type eq 'S') {
	if ($name eq 'rl_line_buffer') {
	    rl_store_var('rl_line_buffer_len', length($value) + 1);
	}
	return _rl_store_str($value, $id);
    } elsif ($type eq 'I') {
	return _rl_store_int($value, $id);
    } elsif ($type eq 'C') {
	return chr(_rl_store_int(ord($value), $id));
    } elsif ($type eq 'F') {
	my $func = $id;
	if ($name eq 'rl_completion_entry_function') {
	    _rl_store_completion_entry_function($value);
	    return $_rl_vars{$name}[1] = $value;
	} elsif ($name eq 'rl_attempted_completion_function') {
	    _rl_store_attempted_completion_function($value);
	    return $_rl_vars{$name}[1] = $value;
	} else {
	    warn "Internal error: Check Gnu.pm\n";
	    return undef;
	}
    } else {
	carp "Term::ReadLine::Gnu::StoreVar: Illegal type `$type'\n";
	return undef;
    }
}

#
#	Custom Completion Support
#

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

If the value of ENTRY_FUNC is false or equals C<'filename'>, built-in
C<filename_completion_function> is used.  If the value equals
C<'username'>, build-in C<username_completion_function> is used.

C<completion_matches> is a perl lapper function of an internal
function C<completion_matches()>.  See also
C<$rl_completion_entry_function>.

=cut

# completion_matches() is defined in Gnu.xs

=item C<list_completion_function(TEXT, STATE)>

A sample generator function defined by Term::ReadLine::Gnu.pm.
Example code at C<rl_completion_entry_function> shows how to use this
function.

=cut

BEGIN {
    my $i;

    sub list_completion_function ($$) {
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

# The following functions are defined in ReadLine.pm.

=item C<IN>, C<OUT>

return the filehandles for input and output or C<undef> if C<readline>
input and output cannot be used for Perl.

=cut

sub IN  { shift->{IN}; }
sub OUT { shift->{OUT}; }

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
#	string variable access function
#
sub TIESCALAR {
    my $class = shift;
    my $id = shift;
    my $self = [$id, _rl_fetch_str($id)];
    return bless $self, $class;
}

sub FETCH {
    my $self = shift;
    confess "wrong type" unless ref $self;
    return _rl_fetch_str($self->[0]);
}

sub STORE {
    my $self = shift;
    confess "wrong type" unless ref $self;
    return _rl_store_str(shift, $self->[0]);
}

1;
__END__

=back

=head1 VARIABLES

Following GNU Readline Library variables can be accessed through
FetchVar and StoreVar methods.  See 'GNU Readline Library Manual' and '
GNU History Library Manual' for each variable.

    'rl_line_buffer'
    'rl_library_version'
    'rl_readline_name'
    'rl_basic_word_break_characters'
    'rl_basic_quote_characters'
    'rl_completer_word_break_characters'
    'rl_completer_quote_characters'
    'rl_filename_quote_characters'
    'rl_special_prefixes'
    'history_no_expand_chars'
    'history_search_delimiter_chars'
       
    'rl_buffer_len'
    'rl_point'
    'rl_end'
    'rl_mark'
    'rl_done'
    'rl_pending_input'
    'rl_completion_query_items'
    'rl_completion_append_character'
    'rl_ignore_completion_duplicates'
    'rl_filename_completion_desired'
    'rl_filename_quoting_desired'
    'rl_inhibit_completion'
    'history_base'
    'history_length'
    'history_expansion_char'
    'history_subst_char'
    'history_comment_char'
    'history_quotes_inhibit_expansion'

    'rl_completion_entry_function'
    'rl_attempted_completion_function'

Following variables need more explanation.

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

If the value is false or equals C<'filename'>, built-in
C<filename_completion_function> is used.  If the value equals
C<'username'>, build-in C<username_completion_function> is used.

A sample generator function, C<list_completion_function>, is defined
in Gnu.pm.  You can use it as follows;

    use Term::ReadLine;
    ...
    my $term = new Term::ReadLine 'sample';
    ...
    $term->StoreVar('rl_completion_entry_function',
		    \&Term::ReadLine::Gnu::list_completion_function);
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

    sub sample_completion {
        my ($text, $line, $start, $end) = @_;
        # If first word then username completion, else filename completion
        if (substr($line, 0, $start) =~ /^\s*$/) {
    	    return Term::ReadLine::Gnu::completion_matches($text, 'username');
        } else {
    	    return ();
        }
    }
    ...
    $term->StoreVar('rl_attempted_completion_function', \&sample_completion);

=back

=head1 FILES

=over 4

=item F<~/.inputrc>

Readline init file.  Using this file it is possible that you would
like to use a different set of keybindings.  When a program which uses
the Readline library starts up, the init file is read, and the key
bindings are set.

Conditional key binding is also available.  The program name which is
specified by the first argument of C<new> method is used as the
application construct.

For example, when your program call C<new> method like this;

	...
	$term = new Term::ReadLine 'PerlSh';
	...

your F<~/.inputrc> can define keybindings only for it as follows;

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

=cut
