#
#	Gnu.pm --- GNU Readline wrapper module
#
#	$Id: Gnu.pm,v 1.3 1996-11-15 15:55:23 hayashi Exp $
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

Term::ReadLine::Gnu - Perl extension for GNU readline library

=head1 SYNOPSIS

  use Term::ReadLine;
  $term = new Term::ReadLine 'ProgramName';
  while ( defined ($_ = $term->readline('prompt>')) ) {
    ...
  }

=head1 DESCRIPTION

This is an implementation of Term::ReadLine using GNU readline library.

=cut

use strict;
use vars qw($VERSION @ISA
	    $rl_basic_word_break_characters);
use Carp;

require Exporter;
require DynaLoader;

@ISA = qw(Term::ReadLine::Stub Exporter DynaLoader);
$VERSION = '0.01';

bootstrap Term::ReadLine::Gnu $VERSION;

# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.

=over 4

=item C<ReadLine>

returns the actual package that executes the commands. If you have
installed this package,  possible value is C<Term::ReadLine::Gnu>.

=cut

sub ReadLine () { 'Term::ReadLine::Gnu'; }

=item C<new(NAME,[IN[,OUT]]>

returns the handle for subsequent calls to following functions.
Argument is the name of the application.  Optionally can be followed
by two arguments for C<IN> and C<OUT> filehandles. These arguments
should be globs.

=cut

# The origin of this function is Term::ReadLine::Perl.pm by Ilya Zakharevich.
sub new ($;$$$) {
    my $this = shift;		# Package
    my $class = ref($this) || $this;

    my $name;
    _rl_set_readline_name($name = shift) if (@_); # Name

    my ($instream, $outstream);
    if (!@_) {
	my ($IN,$OUT) = Term::ReadLine::Stub::findConsole();
	open(IN,"<$IN")   || croak "Cannot open $IN for read";
	open(OUT,">$OUT") || croak "Cannot open $OUT for write";
	_rl_set_instream (fileno($instream  = \*IN));
	_rl_set_outstream(fileno($outstream = \*OUT));
    } else {
	_rl_set_instream (fileno($instream  = shift));
	_rl_set_outstream(fileno($outstream = shift));
    }
    # The following is here since it is mostly used for perl input:
#    $rl_basic_word_break_characters .= '-:+/*,[])}';

    my $self = {
		IN		=> $instream,
		OUT		=> $outstream,
		AppName		=> $name,
		MinLength	=> 1,
		DoExpand	=> 0,
		MaxHist		=> undef,
	       };
    bless $self, $class;
}

=item C<readline(PROMPT[,PREPUT])>

gets an input line, I<possibly> with actual C<readline> support.
Trailing newline is removed.  Returns C<undef> on C<EOF>.  C<PREPUT>
is an optional argument meaning the initial value of input.

The optional argument C<PREPUT> is granted only if the value C<preput>
is in C<Features>.

=cut

sub readline ($;$$) {
    my $self = shift;

    # call readline()
    my $line = _rl_readline(@_);
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

sub addhistory ($@) {		# Why not AddHistory ?
    shift;
    _rl_add_history(@_);
}

=item C<StifleHistory(MAX)>

stifles the history list, remembering only the last C<MAX> entries.
If MAX is undef,  remembers all entries.

=cut

sub StifleHistory ($;$) {
    my $self = shift;
    _stifle_history($self->{MaxHist} = shift);
}

=item C<SetHistory(LINE1, LINE2, ...)>

sets the history of input, from where it can be used if the actual
C<readline> is present.

=cut

sub SetHistory ($@) {
    shift;
    _rl_SetHistory(@_);
}

=item C<GetHistory>

returns the history of input as a list, if actual C<readline> is present.

=cut

sub GetHistory () {
    _rl_GetHistory();
}

=item C<ReadHistory(FILENAME [,FROM [,TO]])>

adds the contents of C<FILENAME> to the history list, a line at a
time.  If C<FILENAME> is false, then read from C<~/.history>.  Start
reading at line C<FROM> and end at C<TO>.  If C<FROM> is omitted or
zero, start at the beginning.  If C<TO> is omittied or less than
C<FROM>, then read until the end of the file.  Returns true if
successful, or false if not.

=cut

sub ReadHistory ($;$$$) {
    shift;
    _rl_read_history(@_);
}

=item C<WriteHistory(FILENAME)>

writes the current history to C<FILENAME>, overwriting C<FILENAME> if
necessary.  If C<FILENAME> is false, then write the history list to
C<~/.history>.  Returns true if successful, or false if not.

=cut

sub WriteHistory ($;$) {
    shift;
    _rl_write_history($_[0]);
}

=item C<MinLine([MAX])>

If argument C<MAX> is specified, it is an advice on minimal size of
line to be included into history.  C<undef> means do not include
anything into history. Returns the old value.

=cut

sub MinLine ($$) {
    my $self = shift;
    my $old_minlength = $self->{MinLength};
    $self->{MinLength} = shift;
    $old_minlength;
}

=item C<$rl_completion_entry_function>

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

     use Term::ReadLine qw(@completion_word_list list_completion_function);
     ...
     my $term = new Term::ReadLine 'sample';
     ...
     @completion_word_list = qw(list of words which you want to use for completion);
     $rl_completion_entry_function = \&list_completion_function;
     $term->readline("custom completion>");

See also C<completion_matches>.

=cut

#
#	access methods for $rl_completion_entry_function
#
package Term::ReadLine::Gnu::CEF;
use Carp;
use strict;

sub TIESCALAR ($) {
    my $class = shift;
    my $self = shift;
    Term::ReadLine::Gnu::_rl_store_completion_entry_function($self);
    return bless \$self, $class;
}

sub FETCH ($) {
    my $self = shift;
    confess "wrong type" unless ref $self;
    return $$self;
}

sub STORE ($$) {
    my $self = shift;
    confess "wrong type" unless ref $self;
    $$self = shift;
    Term::ReadLine::Gnu::_rl_store_completion_entry_function($$self);
    return $$self;
}

#	End of Term::ReadLine::Gnu::CEF

=item C<$rl_attempted_completion_function>

A pointer to an alternative function to create matches.

The function is called with TEXT, LINE_BUFFER, START, and END.
LINE_BUFFER is a current input buffer string.  START and END are
indices in LINE_BUFFER saying what the boundaries of TEXT are.

If this function exists and returns null list or C<undef>, or if this
variable is set to C<undef>, then an internal function
C<rl_complete()> will call the value of
C<$rl_completion_entry_function> to generate matches, otherwise the
array of strings returned will be used.

The default value of this variable is C<undef>.

=cut

#
#	access methods for $rl_attempted_completion_function
#
package Term::ReadLine::Gnu::ACF;
use Carp;
use strict;

sub TIESCALAR ($) {
    my $class = shift;
    my $self = shift;
    Term::ReadLine::Gnu::_rl_store_attempted_completion_function($self);
    return bless \$self, $class;
}

sub FETCH ($) {
    my $self = shift;
    confess "wrong type" unless ref $self;
    return $$self;
}

sub STORE ($$) {
    my $self = shift;
    confess "wrong type" unless ref $self;
    $$self = shift;
    Term::ReadLine::Gnu::_rl_store_attempted_completion_function($$self);
    return $$self;
}

#	End of Term::ReadLine::Gnu::ACF

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

=item C<$rl_basic_word_break_characters>

The basic list of characters that signal a break between words for the
completer routine.  The default value of this variable is the
characters which break words for completion in Bash, i.e.,
C<" \t\n\"\\'`\@\$><=;|&{(">.

=cut

#
#	access methods for $rl_basic_word_break_characters
#
package Term::ReadLine::Gnu::BWBC;
use Carp;
use strict;

sub TIESCALAR ($) {
    my $class = shift;
    my $self = shift;
    Term::ReadLine::Gnu::_rl_store_basic_word_break_characters($self);
    return bless \$self, $class;
}

sub FETCH ($) {
    my $self = shift;
    confess "wrong type" unless ref $self;
    return $$self;
}

sub STORE ($$) {
    my $self = shift;
    confess "wrong type" unless ref $self;
    $$self = shift;
    Term::ReadLine::Gnu::_rl_store_basic_word_break_characters($$self);
    return $$self;
}

#	End of Term::ReadLine::Gnu::CEF

package Term::ReadLine;

use vars qw($rl_completion_entry_function $rl_attempted_completion_function
	    @completion_word_list $rl_basic_word_break_characters
	    %EXPORT_TAGS @EXPORT_OK);

%EXPORT_TAGS = (custom_completion => [qw($rl_completion_entry_function
					 $rl_attempted_completion_function
					 completion_matches
					 @completion_word_list
					 list_completion_function
					 $rl_basic_word_break_characters)]);
Exporter::export_ok_tags('custom_completion');

tie $rl_completion_entry_function, 'Term::ReadLine::Gnu::CEF', undef;
tie $rl_attempted_completion_function, 'Term::ReadLine::Gnu::ACF', undef;
tie $rl_basic_word_break_characters, 'Term::ReadLine::Gnu::BWBC',
    " \t\n\"\\'`\@\$><=;|&{(";	# default value of GNU readline

BEGIN {
    my $i;

    sub list_completion_function ($$) {
	my($text, $state) = @_;
	my $entry;

	$i = $state ? $i + 1 : 0; # clear counter at the first call
	for (; $i <= $#completion_word_list; $i++) {
	    return $entry
		if (($entry = $completion_word_list[$i]) =~ /^$text/);
	}
	return undef;
    }
}

package Term::ReadLine::Gnu;

# The following functions are defined in ReadLine.pm.

=item C<IN>, C<OUT>

return the filehandles for input and output or C<undef> if C<readline>
input and output cannot be used for Perl.

=cut

sub IN  ($) { shift->{IN}; }
sub OUT ($) { shift->{OUT}; }

=item C<findConsole>

returns an array with two strings that give most appropriate names for
files for input and output using conventions C<"<$in">, C<"E<gt>out">.

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
		readHistory => 1, writeHistory => 1,
		tkRunning => 0);

sub Features () { \%Features; }

1;
__END__

=back

=head1 EXPORTS

None

=head1 AUTHOR

Hiroo Hayashi, hayashi@pdcd.ilab.toshiba.co.jp

=head1 SEE ALSO

Term::ReadLine

Term::ReadLine::Perl

perl(1).

=head1 TODO

Perlsh: variable name completion support, POD document

keybind function

document

=cut
