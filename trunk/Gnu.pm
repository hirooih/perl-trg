#
#	Gnu.pm --- GNU Readline wrapper module
#
#	$Id: Gnu.pm,v 1.2 1996-11-09 15:02:44 hayashi Exp $
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
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK
	    $rl_basic_word_break_characters);
use Carp;

require Exporter;
require DynaLoader;

@ISA = qw(Term::ReadLine::Stub Exporter DynaLoader);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw(
);
$VERSION = '0.10';

bootstrap Term::ReadLine::Gnu $VERSION;

# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.

my ($term, $minlength, $rl_readline_name, $rl_instream, $rl_outstream);

=over 4

=item C<ReadLine>

returns the actual package that executes the commands. If you have
installed this package,  possible value is C<Term::ReadLine::Gnu>.

=cut

sub ReadLine () {'Term::ReadLine::Gnu'}

=item C<new([IN[,OUT]]>

returns the handle for subsequent calls to following functions.
Argument is the name of the application.  Optionally can be followed
by two arguments for C<IN> and C<OUT> filehandles. These arguments
should be globs.

=cut

# This function is from Term::ReadLine::Perl.pm by Ilya Zakharevich.
sub new ($;$$$) {
    warn "Cannot create second readline interface.\n" if defined $term;
    shift;			# Package
    if (@_) {
	if ($term) {
	    warn "Ignoring name of second readline interface.\n"
		if defined $term;
	    shift;
	} else {
	    _rl_set_readline_name(shift); # Name
	}
    }
    if (!@_) {
	if (!defined $term) {
	    my ($IN,$OUT) = Term::ReadLine->findConsole();
	    open(IN,"<$IN") || croak "Cannot open $IN for read";
	    open(OUT,">$OUT") || croak "Cannot open $OUT for write";
	    _rl_set_instream(fileno($rl_instream = \*IN));
	    _rl_set_outstream(fileno($rl_outstream = \*OUT));
	}
    } else {
	if (defined $term and ($term->IN ne $_[0] or $term->OUT ne $_[1]) ) {
	    croak "Request for a second readline interface with different terminal";
	}
	_rl_set_instream(fileno($rl_instream = shift));
	_rl_set_outstream(fileno($rl_outstream = shift));
    }
    # The following is here since it is mostly used for perl input:
#    $rl_basic_word_break_characters .= '-:+/*,[])}';
    $term = bless [$rl_instream, $rl_outstream];
}

=item C<readline(PROMPT[,PREPUT[,DO_EXPAND]])>

gets an input line, I<possibly> with actual C<readline> support.
Trailing newline is removed.  Returns C<undef> on C<EOF>.  C<PREPUT>
is an optional argument meaning the initial value of input.
C<DO_EXPAND> is also an optional argument. If this value is true, then
history expansion is done.  The optional argument C<PREPUT> is granted
only if the value C<preput> is in C<Features>.  And C<DO_EXPAND> is
granted only if the value C<do_expand> is in C<Features>.

=cut

sub readline ($;$$$) {
    shift;
    my $do_expand = ($#_ == 2) and pop @_;
    my $line = _rl_readline(@_);
    return undef unless defined $line;

    if ($do_expand) {		# do history expansion
	my $result;
	($result, $line) = history_expand($line);
	print $rl_outstream "$line\n" if ($result);
     
	if ($result < 0 || $result == 2) {
	    return '';		# don't return `undef' which means EOF.
	}
    }

    rl_add_history($line)
	if (defined $minlength and (length($line) >= $minlength));
    return $line;
}

=item C<addhistory(LINE1, LINE2, ...)>

adds the lines to the history of input, from where it can be used if
the actual C<readline> is present.

=cut

sub addhistory ($@) {		# Why not AddHistory ?
    shift;
    rl_add_history(@_);
}

=item C<StifleHistory(MAX)>

stifles the history list, remembering only the last C<MAX> entries.

=cut

sub StifleHistory ($$) {
    shift;
    stifle_history(@_);		# internal function
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

$minlength = 1;

sub MinLine ($$) {
    my $old_minlength = $minlength;
    $minlength = $_[1];
    $old_minlength;
}

=item C<$rl_completion_entry_function>

holds reference refers to the generator function for
C<completion_matches()>.

The generator function is called repeatedly from C<completion_matches
()>, returning a string each time.  The arguments to the generator
function are TEXT and STATE.  TEXT is the partial word to be
completed.  STATE is zero the first time the function is called,
allowing the generator to perform any necessary initialization, and a
positive non-zero integer for each subsequent call.  When the
generator function returns C<undef> this signals C<completion_matches
()> that there are no more possibilities left.

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

use vars qw($rl_basic_word_break_characters $rl_completion_entry_function
	    @completion_word_list @EXPORT_OK);
@EXPORT_OK = qw($rl_basic_word_break_characters $rl_completion_entry_function
		@completion_word_list list_completion_function
);

tie $rl_completion_entry_function, 'Term::ReadLine::Gnu::CEF', undef;
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

my %features = (appname => 1, minline => 1, autohistory => 1,
		preput => 1, do_expand => 1, stifleHistory => 1,
		getHistory => 1, setHistory => 1, addHistory => 1,
		readHistory => 1, writeHistory => 1,
		tkRunning => 0);

sub Features () { \%features; }

1;
__END__

# The following functions are defined in ReadLine.pm.

=item C<IN>, C<OUT>

return the filehandles for input and output or C<undef> if C<readline>
input and output cannot be used for Perl.

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

README, INSTALL manual (libreadline.a)

rl_attempted_completion support.

Perlsh

Make test.pl clean.

=cut
