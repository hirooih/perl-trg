#
#	Gnu.pm --- The GNU Readline/History Library wrapper module
#
#	$Id: Gnu.pm,v 1.58 1999-02-22 15:48:47 hayashi Exp $
#
#	Copyright (c) 1996,1997,1998 Hiroo Hayashi.  All rights reserved.
#
#	This program is free software; you can redistribute it and/or
#	modify it under the same terms as Perl itself.
#
#	Some of documentation strings in this file are cited from the
#	GNU Readline/History Library Manual.

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

=head2 Minimal Set of Methods defined by B<Readline.pm>

=cut

use strict;
use Carp;

{
    use Exporter ();
    use DynaLoader;
    use vars qw($VERSION @ISA @EXPORT_OK);

    $VERSION = '1.03';

    @ISA = qw(Term::ReadLine::Stub Term::ReadLine::Gnu::AU
	      Exporter DynaLoader);

    @EXPORT_OK = qw(RL_PROMPT_START_IGNORE RL_PROMPT_END_IGNORE
		    NO_MATCH SINGLE_MATCH MULT_MATCH
		    ISFUNC ISKMAP ISMACR
		    UNDO_DELETE UNDO_INSERT UNDO_BEGIN UNDO_END);

    bootstrap Term::ReadLine::Gnu $VERSION;
}

#	Global Variables
my $Operate_Index;
my $Next_Operate_Index;

use vars qw(%Attribs %Features @rl_term_set);

%Attribs  = (
	     do_expand => 0,
	     completion_word => [],
	    );
%Features = (
	     appname => 1, minline => 1, autohistory => 1,
	     getHistory => 1, setHistory => 1, addHistory => 1,
	     readHistory => 1, writeHistory => 1,
	     preput => 1, attribs => 1, newTTY => 1,
	     tkRunning => Term::ReadLine::Stub->Features->{'tkRunning'},
	     ornaments => Term::ReadLine::Stub->Features->{'ornaments'},
	     stiflehistory => 1,
	    );

sub Attribs { \%Attribs; }
sub Features { \%Features; }

#
#	GNU Readline/History Library constant definition
#	These are included in @EXPORT_OK.

# for non-printing characters in prompt string
sub RL_PROMPT_START_IGNORE	{ "\001"; }
sub RL_PROMPT_END_IGNORE	{ "\002"; }

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
#	Methods Definition
#

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

# The origin of this function is Term::ReadLine::Perl.pm by Ilya Zakharevich.
sub new {
    my $this = shift;		# Package
    my $class = ref($this) || $this;

    my $name = shift;
    # Don't use this hash.  Use Attribs method instead.
    my $self = {
		MinLength	=> 1,
	       };
    bless $self, $class;

    # set rl_readline_name before .inputrc is read in rl_initialize()
    $Attribs{readline_name} = $name;

    # initialize the GNU Readline Library and termcap library
    $self->initialize();

    # enable ornaments to be compatible with perl5.004_05(?)
    unless ($ENV{PERL_RL} and $ENV{PERL_RL} =~ /\bo\w*=0/) {
	local $^W = 0;		# Term::ReadLine is not warning flag free
	# 'ue' (underline end) does not work on some terminal 
	#$self->ornaments(1);
	$self->ornaments('us,me,,');
    }

    if (!@_) {
	my ($IN,$OUT) = $self->findConsole();
	open(IN,"<$IN")   || croak "Cannot open $IN for read";
	open(OUT,">$OUT") || croak "Cannot open $OUT for write";
	$Attribs{instream} = \*IN;
	$Attribs{outstream} = \*OUT;
    } else {
	$Attribs{instream} = shift;
	$Attribs{outstream} = shift;
    }
    $Operate_Index = $Next_Operate_Index = undef; # for operate_and_get_next()

    $self;
}

sub DESTROY {}

=item C<readline(PROMPT[,PREPUT])>

gets an input line, with actual C<GNU Readline> support.  Trailing
newline is removed.  Returns C<undef> on C<EOF>.  C<PREPUT> is an
optional argument meaning the initial value of input.

The optional argument C<PREPUT> is granted only if the value C<preput>
is in C<Features>.

C<PROMPT> may include some escape sequences.  Use
C<RL_PROMPT_START_IGNORE> to begin a sequence of non-printing
characters, and C<RL_PROMPT_END_IGNORE> to end of such a sequence.

=cut

use vars qw($_Preput $_Saved_Startup_Hook);

# to peacify -w
$Term::ReadLine::registered = $Term::ReadLine::registered;

sub readline {			# should be ReadLine
    my $self = shift;
    my ($prompt, $preput) = @_;

    # ornament support (now prompt only)
    # non-printing characters must be told to readline
    $prompt = RL_PROMPT_START_IGNORE . $rl_term_set[0] . RL_PROMPT_END_IGNORE
	. $prompt
	    . RL_PROMPT_START_IGNORE . $rl_term_set[1] . RL_PROMPT_END_IGNORE;

    # TkRunning support
    if (not $Term::ReadLine::registered and $Term::ReadLine::toloop
	and defined &Tk::DoOneEvent) {
	$self->register_Tk;
	$Attribs{getc_function} = \&Tk_getc;
    }

    # cf. operate_and_get_next()
    if (defined $Operate_Index) {
	$Next_Operate_Index = $Operate_Index + 1;
	my $next_line = $self->history_get($Next_Operate_Index);
	$preput = $next_line if defined $next_line;
	undef $Operate_Index;
    }

    # call readline()
    my $line;
    if (defined $preput) {
	$_Preput = $preput;
	$_Saved_Startup_Hook = $Attribs{startup_hook};
	$Attribs{startup_hook} = sub {
	    $self->rl_insert_text($_Preput);
	    &$_Saved_Startup_Hook
		if defined $_Saved_Startup_Hook;
	};
	$line = Term::ReadLine::Gnu::XS::rl_readline($prompt);
	$Attribs{startup_hook} = $_Saved_Startup_Hook;
    } else {
	$line = Term::ReadLine::Gnu::XS::rl_readline($prompt);
    }
    undef $Next_Operate_Index;
    return undef unless defined $line;

    # history expansion
    if ($Attribs{do_expand}) {
	my $result;
	($result, $line) = $self->history_expand($line);
	my $outstream = $Attribs{outstream};
	print $outstream "$line\n" if ($result);
     
	# return without adding line into history
	if ($result < 0 || $result == 2) {
	    return '';		# don't return `undef' which means EOF.
	}
    }

    # add to history buffer
    $self->add_history($line) 
       if ($self->{MinLength} > 0 && length($line) >= $self->{MinLength});

    return $line;
}

sub Tk_getc {
    &Term::ReadLine::Tk::Tk_loop
	if $Term::ReadLine::toloop && defined &Tk::DoOneEvent;
    my $FILE = $Attribs{instream};
    return Term::ReadLine::Gnu::XS::rl_getc($FILE);
}

=item C<AddHistory(LINE1, LINE2, ...)>

adds the lines to the history of input, from where it can be used if
the actual C<readline> is present.

=cut

use vars '*addhistory';
*addhistory = \&AddHistory;	# for backward compatibility

sub AddHistory {
    my $self = shift;
    foreach (@_) {
	$self->add_history($_);
    }
}

=item C<IN>, C<OUT>

return the file handles for input and output or C<undef> if
C<readline> input and output cannot be used for Perl.

=cut

sub IN  { $Attribs{instream}; }
sub OUT { $Attribs{outstream}; }

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
    
# findConsole is defined in ReadLine.pm.

=item C<findConsole>

returns an array with two strings that give most appropriate names for
files for input and output using conventions C<"E<lt>$in">, C<"E<gt>$out">.

=item C<Attribs>

returns a reference to a hash which describes internal configuration
(variables) of the package.  Names of keys in this hash conform to
standard conventions with the leading C<rl_> stripped.

See section "Variables" for supported variables.

=item C<Features>

Returns a reference to a hash with keys being features present in
current implementation. Several optional features are used in the
minimal interface: C<appname> should be present if the first argument
to C<new> is recognized, and C<minline> should be present if
C<MinLine> method is not dummy.  C<autohistory> should be present if
lines are put into history automatically (maybe subject to
C<MinLine>), and C<addHistory> if C<AddHistory> method is not dummy. 
C<preput> means the second argument to C<readline> method is processed.
C<getHistory> and C<setHistory> denote that the corresponding methods are 
present. C<tkRunning> denotes that a Tk application may run while ReadLine
is getting input B<(undocumented feature)>.

=back

=cut

# This routine originates in Term::ReadLine.pm.

# Debian GNU/Linux discourages users from using /etc/termcap.  A
# subroutine ornaments() defined in Term::ReadLine.pm uses
# Term::Caps.pm which requires /etc/termcap.

# This module calls termcap (or its compatible) library, which the GNU
# Readline Library already uses, instead of Term::Caps.pm.
{
    # Prompt-start, prompt-end, command-line-start, command-line-end
    #     -- zero-width beautifies to emit around prompt and the command line.
    @rl_term_set = ("","","","");
    # string encoded:
    my $rl_term_set = ',,,';

    sub ornaments {
	shift;
	return $rl_term_set unless @_;
	$rl_term_set = shift;
	$rl_term_set ||= ',,,';
	$rl_term_set = 'us,me,,' if $rl_term_set eq '1';
	my @ts = split /,/, $rl_term_set, 4;
	@rl_term_set
	    = map {$_ ? Term::ReadLine::Gnu::TermCap::_tgetstr($_) || '' : ''} @ts;
	return $rl_term_set;
    }
}

# Not tested yet.  How do I use this?
sub newTTY {
    my ($self, $in, $out) = @_;
    $Attribs{instream}  = $in;
    $Attribs{outstream} = $out;
    my $sel = select($out);
    $| = 1;			# for DB::OUT
    select($sel);
}


#
#	Additional Supported Methods
#

# Documentation is after '__END__' for efficiency.

# for backward compatibility
use vars qw(*AddDefun *BindKey *UnbindKey *ParseAndBind *StifleHistory);
*AddDefun = \&add_defun;
*BindKey = \&bind_key;
*UnbindKey = \&unbind_key;
*ParseAndBind = \&parse_and_bind;
*StifleHistory = \&stifle_history;

sub SetHistory {
    my $self = shift;
    $self->clear_history();
    $self->AddHistory(@_);
}

sub GetHistory {
    my $self = shift;
    $self->history_list();
}

sub ReadHistory {
    my $self = shift;
    ! $self->read_history_range(@_);
}

sub WriteHistory {
    my $self = shift;
    ! $self->write_history(@_);
}

package Term::ReadLine::Gnu::XS;
use Carp;
use strict;

#
#	Readline Library function wrappers
#

# Convert keymap name to Keymap if the argument is not reference to Keymap
sub _str2map ($) {
    return ref $_[0] ? $_[0]
	: (rl_get_keymap_by_name($_[0]) || carp "unknown keymap name \`$_[0]\'\n");
}

# Convert function name to Function if the argument is not reference
# to Function
sub _str2fn ($) {
    return ref $_[0] ? $_[0]
	: (rl_named_function($_[0]) || carp "unknown function name \`$_[0]\'\n");
}

sub rl_copy_keymap ($)    { return _rl_copy_keymap(_str2map($_[0])); }
sub rl_discard_keymap ($) { return _rl_discard_keymap(_str2map($_[0])); }
sub rl_set_keymap ($)     { return _rl_set_keymap(_str2map($_[0])); }

sub rl_bind_key ($$;$) {
    if (defined $_[2]) {
	return _rl_bind_key($_[0], _str2fn($_[1]), _str2map($_[2]));
    } else {
	return _rl_bind_key($_[0], _str2fn($_[1]));
    }
}

sub rl_unbind_key ($;$) {
    if (defined $_[1]) {
	return _rl_unbind_key($_[0], _str2map($_[1]));
    } else {
	return _rl_unbind_key($_[0]);
    }
}

sub rl_unbind_function_in_map ($;$) {
    # libreadline.* in Debian GNU/Linux 2.0 tells wrong value as '2.1-bash'
    my ($version) = $Term::ReadLine::Gnu::Attribs{library_version}
	=~ /(\d+\.\d+)/;
    if ($version < 2.2) {
	carp "rl_unbind_function_in_map() is not supported.  Ignored\n";
	return;
    }
    if (defined $_[1]) {
	return _rl_unbind_function_in_map($_[0], _str2map($_[1]));
    } else {
	return _rl_unbind_function_in_map($_[0]);
    }
}

sub rl_unbind_command_in_map ($;$) {
    my ($version) = $Term::ReadLine::Gnu::Attribs{library_version}
	=~ /(\d+\.\d+)/;
    if ($version < 2.2) {
	carp "rl_unbind_command_in_map() is not supported.  Ignored\n";
	return;
    }
    if (defined $_[1]) {
	return _rl_unbind_command_in_map($_[0], _str2map($_[1]));
    } else {
	return _rl_unbind_command_in_map($_[0]);
    }
}

sub rl_generic_bind ($$$;$) {
    if      ($_[0] == Term::ReadLine::Gnu::ISFUNC) {
	if (defined $_[3]) {
	    _rl_generic_bind_function($_[1], _str2fn($_[2]), _str2map($_[3]));
	} else {
	    _rl_generic_bind_function($_[1], _str2fn($_[2]));
	}
    } elsif ($_[0] == Term::ReadLine::Gnu::ISKMAP) {
	if (defined $_[3]) {
	    _rl_generic_bind_keymap($_[1], _str2map($_[2]), _str2map($_[3]));
	} else {
	    _rl_generic_bind_keymap($_[1], _str2map($_[2]));
	}
    } elsif ($_[0] == Term::ReadLine::Gnu::ISMACR) {
	if (defined $_[3]) {
	    _rl_generic_bind_macro($_[1], $_[2], _str2map($_[3]));
	} else {
	    _rl_generic_bind_macro($_[1], $_[2]);
	}
    } else {
	carp("Term::ReadLine::Gnu::rl_generic_bind: invalid \`type\'\n");
    }
}
	    
sub rl_call_function ($;$$) {
    if (defined $_[2]) {
	return _rl_call_function(_str2fn($_[0]), $_[1], $_[2]);
    } elsif (defined $_[1]) {
	return _rl_call_function(_str2fn($_[0]), $_[1]);
    } else {
	return _rl_call_function(_str2fn($_[0]));
    }
}

sub rl_invoking_keyseqs ($;$) {
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

# _rl_save_prompt() and _rl_restore_prompt() are not documented
# in the GNU Readline Library Manual Version 2.2.
sub rl_save_prompt {
    _rl_save_prompt();
}

sub rl_restore_prompt {
    _rl_restore_prompt();
}

#
#	List Completion Function
#

{
    my $i;

    sub list_completion_function ( $$ ) {
	my($text, $state) = @_;

	$i = $state ? $i + 1 : 0; # clear counter at the first call
	my $cw = $Term::ReadLine::Gnu::Attribs{completion_word};
	for (; $i <= $#{$cw}; $i++) {
	    return $cw->[$i] if ($cw->[$i] =~ /^$text/);
	}
	return undef;
    }
}

#
#	a sample custom function
#
#	defined in this module for the compatibility with bash and
#	Term::ReadLine::Perl
#
sub operate_and_get_next {
    my ($count, $key) = @_;

    if (defined $Next_Operate_Index) {
	history_set_pos($Next_Operate_Index
			- $Term::ReadLine::Gnu::Attribs{history_base});
	undef $Next_Operate_Index;
    }
    rl_call_function("accept-line", $count, $key);

    $Operate_Index
	= $Term::ReadLine::Gnu::Attribs{history_base} + where_history();
}

rl_add_defun('operate-and-get-next', \&operate_and_get_next, ord "\co");

#
#	for compatibility with Term::ReadLine::Perl
#
sub filename_list {
    shift;
    my ($text) = @_;
    return completion_matches($text, \&filename_completion_function);
}

#
#	History Library function wrappers
#
sub history_list () {
    my ($i, $history_base, $history_length, @d);
    $history_base   = $Term::ReadLine::Gnu::Attribs{history_base};
    $history_length = $Term::ReadLine::Gnu::Attribs{history_length};
    for ($i = $history_base; $i < $history_base + $history_length; $i++) {
	push(@d, history_get($i));
    }
    @d;
}

sub history_arg_extract ( ;$$$ ) {
    my ($line, $first, $last) = @_;
    $line  = $_      unless defined $line;
    $first = 0       unless defined $first;
    $last  = ord '$' unless defined $last; # '
    $first = ord '$' if defined $first and $first eq '$'; # '
    $last  = ord '$' if defined $last  and $last  eq '$'; # '
    &_history_arg_extract($line, $first, $last);
}

use vars qw(*read_history);
*read_history = \&read_history_range;

sub get_history_event ( $$;$ ) {
    _get_history_event($_[0], $_[1], defined $_[2] ? ord $_[2] : 0);
}

#
#	Access Routines for GNU Readline/History Library Variables
#
package Term::ReadLine::Gnu::Var;
use Carp;
use strict;
use vars qw(%_rl_vars);

%_rl_vars
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
       max_input_history			=> ['I', 13],
       history_expansion_char			=> ['C', 14],
       history_subst_char			=> ['C', 15],
       history_comment_char			=> ['C', 16],
       history_quotes_inhibit_expansion		=> ['I', 17],

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

sub TIESCALAR {
    my $class = shift;
    my $name = shift;
    return bless \$name, $class;
}

sub FETCH {
    my $self = shift;
    confess "wrong type" unless ref $self;

    my $name = $$self;
    if (! defined $_rl_vars{$name}) {
	confess "Term::ReadLine::Gnu::Var::FETCH: Unknown variable name `$name'\n";
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
	carp "Term::ReadLine::Gnu::Var::FETCH: Illegal type `$type'\n";
	return undef;
    }
}

sub STORE {
    my $self = shift;
    confess "wrong type" unless ref $self;

    my $name = $$self;
    if (! defined $_rl_vars{$name}) {
	confess "Term::ReadLine::Gnu::Var::STORE: Unknown variable name `$name'\n";
	return undef ;
    }
    
    my $value = shift;
    my ($type, $id) = @{$_rl_vars{$name}};
    if ($type eq 'S') {
	if ($name eq 'rl_line_buffer') {
	    return _rl_store_rl_line_buffer($value);
	} else {
	    return _rl_store_str($value, $id);
	}
    } elsif ($type eq 'I') {
	return _rl_store_int($value, $id);
    } elsif ($type eq 'C') {
	return chr(_rl_store_int(ord($value), $id));
    } elsif ($type eq 'F') {
	return _rl_store_function($value, $id);
    } elsif ($type eq 'IO') {
	return _rl_store_iostream($value, $id);
    } elsif ($type eq 'K') {
	carp "Term::ReadLine::Gnu::Var::STORE: read only variable `$name'\n";
	return undef;
    } else {
	carp "Term::ReadLine::Gnu::Var::STORE: Illegal type `$type'\n";
	return undef;
    }
}

package Term::ReadLine::Gnu;
use Carp;
use strict;

#
#	set value of %Attribs
#

#	Tie all Readline/History variables
foreach (keys %Term::ReadLine::Gnu::Var::_rl_vars) {
    my $name;
    ($name = $_) =~ s/^rl_//;	# strip leading `rl_'
    tie $Attribs{$name},  'Term::ReadLine::Gnu::Var', $_;
}

#	add reference to some functions
{
    my ($name, $fname);
    no strict 'refs';
    map {
	($name = $_) =~ s/^rl_//; # strip leading `rl_'
	$fname = 'Term::ReadLine::Gnu::XS::' . $_;
	$Attribs{$name} = \&$fname; # symbolic reference
    } qw(rl_getc
	 rl_callback_read_char
	 filename_completion_function
	 username_completion_function
	 list_completion_function);
}

#
#	for compatibility with Term::ReadLine::Gnu
#
tie $Attribs{completion_function}, 'Term::ReadLine::Gnu::Var',
    'rl_attempted_completion_function';

package Term::ReadLine::Gnu::AU;
use Carp;
no strict;

sub AUTOLOAD {
    { $AUTOLOAD =~ s/.*:://; }	# preserve match data
    my $name;
    if (exists $Term::ReadLine::Gnu::XS::{"$AUTOLOAD"}) {
	$name = "Term::ReadLine::Gnu::XS::$AUTOLOAD";
    } elsif (exists $Term::ReadLine::Gnu::XS::{"rl_$AUTOLOAD"}) {
	$name = "Term::ReadLine::Gnu::XS::rl_$AUTOLOAD";
    } else {
	croak "Cannot do `$AUTOLOAD' in Term::ReadLine::Gnu";
    }
    local $^W = 0;		# Why is this line necessary ?
    *$AUTOLOAD = sub { shift; &$name(@_); };
    goto &$AUTOLOAD;
}
1;
__END__


=head1 Additional Supported Methods

All these GNU Readline/History Library functions are callable via
method interface and have names which conform to standard conventions
with the leading C<rl_> stripped.

Almost methods have lower level functions in
C<Term::ReadLine::Gnu::XS> package.  To use them full qualified name
is required.  Using method interface is preferred.

=head2 Readline Convenience Functions

=over 4

=item Naming Function

=over 4

=item C<add_defun(NAME, FUNC [,KEY=-1])>

Add name to the Perl function C<FUNC>.  If optional argument C<KEY> is
specified, bind it to the C<FUNC>.  Returns reference to
C<FunctionPtr>.

  Example:
	# name name `reverse-line' to a function reverse_line(),
	# and bind it to "\C-t"
	$term->add_defun('reverse-line', \&reverse_line, "\ct");

=back

=item Selecting a Keymap

=over 4

=item C<make_bare_keymap>

	Keymap	rl_make_bare_keymap()

=item C<copy_keymap(MAP)>

	Keymap	rl_copy_keymap(Keymap|str map)

=item C<make_keymap>

	Keymap	rl_make_keymap()

=item C<discard_keymap(MAP)>

	Keymap	rl_discard_keymap(Keymap|str map)

=item C<get_keymap>

	Keymap	rl_get_keymap()

=item C<set_keymap(MAP)>

	Keymap	rl_set_keymap(Keymap|str map)

=item C<get_keymap_by_name(NAME)>

	Keymap	rl_get_keymap_by_name(str name)

=item C<get_keymap_name(MAP)>

	str	rl_get_keymap_name(Keymap map)

=back

=item Binding Keys

=over 4

=item C<bind_key(KEY, FUNCTION [,MAP])>

	int	rl_bind_key(int key, FunctionPtr|str function,
			    Keymap|str map = rl_get_keymap())

Bind C<KEY> to the C<FUNCTION>.  C<FUNCTION> is the name added by the
C<add_defun> method.  If optional argument C<MAP> is specified, binds
in C<MAP>.  Returns non-zero in case of error.

=item C<unbind_key(KEY [,MAP])>

	int	rl_unbind_key(int key, Keymap|str map = rl_get_keymap())

Bind C<KEY> to the null function.  Returns non-zero in case of error.

=item C<unbind_function_in_map(FUNCTION [,MAP])>

	int	rl_unbind_function_in_map(FunctionPtr|str function,
					  Keymap|str map = rl_get_keymap())

=item C<unbind_command_in_map(COMMAND [,MAP])>

	int	rl_unbind_command_in_map(str command,
					 Keymap|str map = rl_get_keymap())

=item C<generic_bind(TYPE, KEYSEQ, DATA, [,MAP])>

	int	rl_generic_bind(int type, str keyseq,
				FunctionPtr|Keymap|str data,
				Keymap|str map = rl_get_keymap())

=item C<parse_and_bind(LINE)>

	void	rl_parse_and_bind(str line)

Parse C<LINE> as if it had been read from the F<~/.inputrc> file and
perform any key bindings and variable assignments found.  For more
detail see 'GNU Readline Library Manual'.

=item C<read_init_file([FILENAME])>

	int	rl_read_init_file(str filename = '~/.inputrc')

=back

=item Associating Function Names and Bindings

=over 4

=item C<call_function(FUNCTION, [COUNT [,KEY]])>

	int	rl_call_function(FunctionPtr|str function, count = 1, key = -1)

=item C<named_function(NAME)>

	FunctionPtr rl_named_function(str name)

=item C<get_function_name(FUNCTION)>

	str	rl_get_function_name(FunctionPtr function)

=item C<function_of_keyseq(KEYMAP [,MAP])>

	(FunctionPtr|Keymap|str data, int type)
		rl_function_of_keyseq(str keyseq,
				      Keymap|str map = rl_get_keymap())

=item C<invoking_keyseqs(FUNCTION [,MAP])>

	(@str)	rl_invoking_keyseqs(FunctionPtr|str function,
				    Keymap|str map = rl_get_keymap())

=item C<function_dumper([READABLE])>

	void	rl_function_dumper(int readable = 0)

=item C<list_funmap_names>

	void	rl_list_funmap_names()

=back

=item Allowing Undoing

=over 4

=item C<begin_undo_group>

	int	rl_begin_undo_group()

=item C<end_undo_group>

	int	rl_end_undo_group()

=item C<add_undo(WHAT, START, END, TEXT)>

	int	rl_add_undo(int what, int start, int end, str text)

=item C<free_undo_list>

	void	free_undo_list()

=item C<do_undo>

	int	rl_do_undo()

=item C<modifying([START [,END]])>

	int	rl_modifying(int start = 0, int end = rl_end)

=back

=item Redisplay

=over 4

=item C<redisplay>

	void	rl_redisplay()

=item C<forced_update_display>

	int	rl_forced_update_display()

=item C<on_new_line>

	int	rl_on_new_line()

=item C<reset_line_state>

	int	rl_reset_line_state()

=item C<message(FMT[, ...])>

	int	rl_message(str fmt, ...)

=item C<clear_message>

	int	rl_clear_message()

=back

=item Modifying Text

=over 4

=item C<insert_text(TEXT)>

	int	rl_insert_text(str text)

=item C<delete_text([START [,END]])>

	int	rl_delete_text(start = 0, end = rl_end)

=item C<copy_text([START [,END]])>

	str	rl_copy_text(start = 0, end = rl_end)

=item C<kill_text([START [,END]])>

	int	rl_kill_text(start = 0, end = rl_end)

=back

=item Utility Functions

=over 4

=item C<read_key>

	int	rl_read_key()

=item C<getc(FILE)>

	int	rl_getc(FILE *)

=item C<stuff_char(C)>

	int	rl_stuff_char(int c)

=item C<initialize>

	int	rl_initialize()

=item C<reset_terminal([TERMINAL_NAME])>

	int	rl_reset_terminal(str terminal_name = getenv($TERM))

=item C<ding>

	int	ding()

=back

=item Alternate Interface

=over 4

=item C<callback_handler_install(PROMPT, LHANDLER)>

	void	rl_callback_handler_install(str prompt, pfunc lhandler)

=item C<callback_read_char>

	void	rl_callback_read_char()

=item C<callback_handler_remove>

	void	rl_callback_handler_remove()

=back

=back

=head2 Completion Functions

=over 4

=item C<complete_internal([WHAT_TO_DO])>

	int	rl_complete_internal(int what_to_do = TAB)

=item C<completion_matches(TEXT [,FUNC])>

	(@str)	completion_matches(str text,
				   pfunc func = filename_completion_function)

=item C<filename_completion_function(TEXT, STATE)>

	str	filename_completion_function(str text, int state)

=item C<username_completion_function(TEXT, STATE)>

	str	username_completion_function(str text, int state)

=item C<listname_completion_function(TEXT, STATE)>

	str	list_completion_function(str text, int state)

=back

=head2 History Functions

=over 4

=item Initializing History and State Management

=over 4

=item C<using_history>

	void	using_history()

=back

=item History List Management

=over 4

=item C<addhistory(STRING[, STRING, ...])>

	void	add_history(str string)

=item C<StifleHistory(MAX)>

	int	stifle_history(int max|undef)

stifles the history list, remembering only the last C<MAX> entries.
If C<MAX> is undef, remembers all entries.  This is a replacement
of unstifle_history().

=item C<unstifle_history>

	int	unstifle_history()

This is equivalent with 'stifle_history(undef)'.

=item C<SetHistory(LINE1 [, LINE2, ...])>

sets the history of input, from where it can be used if the actual
C<readline> is present.

=item C<remove_history(WHICH)>

	str	remove_history(int which)

=item C<replace_history_entry(WHICH, LINE)>

	str	replace_history_entry(int which, str line)

=item C<clear_history>

	void	clear_history()

=item C<history_is_stifled>

	int	history_is_stifled()

=back

=item Information About the History List

=over 4

=item C<where_history>

	int	where_history()

=item C<current_history>

	str	current_history()

=item C<history_get(OFFSET)>

	str	history_get(offset)

=item C<history_total_bytes>

	int	history_total_bytes()

=item C<GetHistory>

returns the history of input as a list, if actual C<readline> is present.

=back

=item Moving Around the History List

=over 4

=item C<history_set_pos(POS)>

	int	history_set_pos(int pos)

=item C<previous_history>

	str	previous_history()

=item C<next_history>

	str	next_history()

=back

=item Searching the History List

=over 4

=item C<history_search(STRING [,DIRECTION])>

	int	history_search(str string, int direction = -1)

=item C<history_search_prefix(STRING [,DIRECTION])>

	int	history_search_prefix(str string, int direction = -1)

=item C<history_search_pos(STRING [,DIRECTION [,POS]])>

	int	history_search_pos(str string,
				   int direction = -1,
				   int pos = where_history())

=back

=item Managing the History File

=over 4

=item C<ReadHistory([FILENAME [,FROM [,TO]]])>

	int	read_history(str filename = '~/.history',
			     int from = 0, int to = -1)

	int	read_history_range(str filename = '~/.history',
				   int from = 0, int to = -1)

adds the contents of C<FILENAME> to the history list, a line at a
time.  If C<FILENAME> is false, then read from F<~/.history>.  Start
reading at line C<FROM> and end at C<TO>.  If C<FROM> is omitted or
zero, start at the beginning.  If C<TO> is omitted or less than
C<FROM>, then read until the end of the file.  Returns true if
successful, or false if not.  C<read_history()> is an aliase of
C<read_history_range()>.

=item C<WriteHistory([FILENAME])>

	int	write_history(str filename = '~/.history')

writes the current history to C<FILENAME>, overwriting C<FILENAME> if
necessary.  If C<FILENAME> is false, then write the history list to
F<~/.history>.  Returns true if successful, or false if not.


=item C<append_history(NELEMENTS [,FILENAME])>

	int	append_history(int nelements, str filename = '~/.history')

=item C<history_truncate_file([FILENAME [,NLINES]])>

	int	history_truncate_file(str filename = '~/.history',
				      int nlines = 0)

=back

=item History Expansion

=over 4

=item C<history_expand(LINE)>

	(int result, str expansion) history_expand(str line)

=item C<history_arg_extract(LINE, [FIRST [,LAST]])>

	str history_arg_extract(str line, int first = 0, int last = '$')

=cut

# '	to make emacs font-lock happy

=item C<get_history_event(STRING, CINDEX [,QCHAR])>

	(str text, int cindex) = get_history_event(str  string,
						   int  cindex,
						   char qchar = '\0')

=item C<history_tokenize(LINE)>

	(@str)	history_tokenize(str line)

=back

=back

=head1 Variables

Following GNU Readline/History Library variables can be accessed from
Perl program.  See 'GNU Readline Library Manual' and ' GNU History
Library Manual' for each variable.  You can access them with
C<Attribs> methods.  Names of keys in this hash conform to standard
conventions with the leading C<rl_> stripped.

Examples:

    $attribs = $term->Attribs;
    $v = $attribs->{library_version};	# rl_library_version
    $v = $attribs->{history_base};	# history_base

=over 4

=item Readline Variables

	str rl_line_buffer
	int rl_point
	int rl_end
	int rl_mark
	int rl_done		
	int rl_pending_input
	str rl_prompt (read only)
	str rl_library_version (read only)
	str rl_terminal_name
	str rl_readline_name
	filehandle rl_instream
	filehandle rl_outstream
	pfunc rl_startup_hook
	pfunc rl_event_hook
	pfunc rl_getc_function
	pfunc rl_redisplay_function
	Keymap rl_executing_keymap (read only)
	Keymap rl_binding_keymap (read only)

=item Completion Variables

	pfunc rl_completion_entry_function
	pfunc rl_attempted_completion_function
	rl_filename_quoting_function (not implemented)
	rl_filename_dequoting_function (not implemented)
	rl_char_is_quoted_p (not implemented)
	int rl_completion_query_items
	str rl_basic_word_break_characters
	str rl_basic_quote_characters
	str rl_completer_word_break_characters
	str rl_completer_quote_characters
	str rl_filename_quote_characters
	str rl_special_prefixes
	int rl_completion_append_character
	int rl_ignore_completion_duplicates
	int rl_filename_completion_desired
	int rl_filename_quoting_desired
	int rl_inhibit_completion
	rl_ignore_some_completion_function (not implemented)
	rl_directory_completion_hook (not implemented)

=item History Variables

	int history_base
	int history_length
	int max_input_history (read only)
	char history_expansion_char
	char history_subst_char
	char history_comment_char
	str history_no_expand_chars
	str history_search_delimiter_chars
	int history_quotes_inhibit_expansion

=item Function References

	rl_getc
	rl_callback_read_char
	filename_completion_function
	username_completion_function
	list_completion_function

=item C<Term::ReadLine::Gnu> Specific Variables

	do_expand		# if true history expansion is enabled
	completion_word		# for list_completion_function

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
to the generator function are C<TEXT> and C<STATE>.  C<TEXT> is the
partial word to be completed.  C<STATE> is zero the first time the
function is called, allowing the generator to perform any necessary
initialization, and a positive non-zero integer for each subsequent
call.  When the generator function returns C<undef> this signals
C<completion_matches()> that there are no more possibilities left.

If the value is undef, built-in C<filename_completion_function> is
used.

A sample generator function, C<list_completion_function>, is defined
in Gnu.pm.  You can use it as follows;

    use Term::ReadLine;
    ...
    my $term = new Term::ReadLine 'sample';
    my $attribs = $term->Attribs;
    ...
    $attribs->{completion_entry_function} =
	$attribs->{'list_completion_function'};
    ...
    $attribs->{completion_word} =
	[qw(reference to a list of words which you want to use for completion)];
    $term->readline("custom completion>");

See also C<completion_matches>.

=item C<rl_attempted_completion_function>

A reference to an alternative function to create matches.

The function is called with C<TEXT>, C<LINE_BUFFER>, C<START>, and
C<END>.  C<LINE_BUFFER> is a current input buffer string.  C<START>
and C<END> are indices in C<LINE_BUFFER> saying what the boundaries of
C<TEXT> are.

If this function exists and returns null list or C<undef>, or if this
variable is set to C<undef>, then an internal function
C<rl_complete()> will call the value of
C<$rl_completion_entry_function> to generate matches, otherwise the
array of strings returned will be used.

The default value of this variable is C<undef>.  You can use it as follows;

    use Term::ReadLine;
    ...
    my $term = new Term::ReadLine 'sample';
    my $attribs = $term->Attribs;
    ...
    sub sample_completion {
        my ($text, $line, $start, $end) = @_;
        # If first word then username completion, else filename completion
        if (substr($line, 0, $start) =~ /^\s*$/) {
    	    return $term->completion_matches($text,
					     $attribs->{'username_completion_function'});
        } else {
    	    return ();
        }
    }
    ...
    $attribs->{attempted_completion_function} = \&sample_completion;

=item C<completion_matches(TEXT, ENTRY_FUNC)>

Returns an array of strings which is a list of completions for
C<TEXT>.  If there are no completions, returns C<undef>.  The first
entry in the returned array is the substitution for C<TEXT>.  The
remaining entries are the possible completions.

C<ENTRY_FUNC> is a generator function which has two arguments, and
returns a string.  The first argument is C<TEXT>.  The second is a
state argument; it is zero on the first call, and non-zero on
subsequent calls.  C<ENTRY_FUNC> returns a C<undef> to the caller when
there are no more matches.

If the value of C<ENTRY_FUNC> is undef, built-in
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

Term::ReadLine::Perl (Term-ReadLine-Perl-xx.tar.gz)

=head1 AUTHOR

Hiroo Hayashi <hiroo.hayashi@computer.org>

http://www.perl.org/CPAN/authors/Hiroo_HAYASHI/

=head1 TODO

Test routines for following variable and functions are required.

	rl_read_key()
	rl_stuff_char()

	rl_callback_handler_install()
	rl_callback_read_char()
	rl_callback_handler_remove()

	rl_complete_internal()

=head1 BUGS

rl_add_defun() can define up to 16 functions.

Ornament feature works only on prompt strings.  It requires very hard
hacking of display.c:rl_redisplay() in GNU Readline library to
ornament input line.

newTTY() is not tested yet.

=cut
