#!/usr/local/bin/perl
#
#	XS.pm : perl function definition for Term::ReadLine::Gnu
#
#	$Id: XS.pm,v 1.1 1999-03-15 14:31:43 hayashi Exp $
#
#	Copyright (c) 1996-1999 Hiroo Hayashi.  All rights reserved.
#
#	This program is free software; you can redistribute it and/or
#	modify it under the same terms as Perl itself.

package Term::ReadLine::Gnu::XS;
use Carp;
use strict;
use AutoLoader 'AUTOLOAD';

use vars qw(%Attribs);
*Attribs = \%Term::ReadLine::Gnu::Attribs;

# For backward compatibility.  Using these name (*_in_map) is deprecated.
use vars qw(*rl_unbind_function_in_map *rl_unbind_command_in_map);
*rl_unbind_function_in_map = \&rl_unbind_function;
*rl_unbind_command_in_map  = \&rl_unbind_command;

#
#	List Completion Function
#

{
    my $i;

    sub list_completion_function ( $$ ) {
	my($text, $state) = @_;

	$i = $state ? $i + 1 : 0; # clear counter at the first call
	my $cw = $Attribs{completion_word};
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

    if (defined $Term::ReadLine::Gnu::Next_Operate_Index) {
	history_set_pos($Term::ReadLine::Gnu::Next_Operate_Index
			- $Attribs{history_base});
	undef $Term::ReadLine::Gnu::Next_Operate_Index;
    }
    rl_call_function("accept-line", $count, $key);

    $Term::ReadLine::Gnu::Operate_Index
	= $Attribs{history_base} + where_history();
}

rl_add_defun('operate-and-get-next', \&operate_and_get_next, ord "\co");

use vars qw(*read_history);
*read_history = \&read_history_range;

#
#	for tkRunning
#
sub Tk_getc {
    &Term::ReadLine::Tk::Tk_loop
	if $Term::ReadLine::toloop && defined &Tk::DoOneEvent;
    my $FILE = $Attribs{instream};
    return rl_getc($FILE);
}

1;

__END__

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

sub rl_unbind_function ($;$) {
    # libreadline.* in Debian GNU/Linux 2.0 tells wrong value as '2.1-bash'
    my ($version) = $Attribs{library_version}
	=~ /(\d+\.\d+)/;
    if ($version < 2.2) {
	carp "rl_unbind_function() is not supported.  Ignored\n";
	return;
    }
    if (defined $_[1]) {
	return _rl_unbind_function($_[0], _str2map($_[1]));
    } else {
	return _rl_unbind_function($_[0]);
    }
}

sub rl_unbind_command ($;$) {
    my ($version) = $Attribs{library_version}
	=~ /(\d+\.\d+)/;
    if ($version < 2.2) {
	carp "rl_unbind_command() is not supported.  Ignored\n";
	return;
    }
    if (defined $_[1]) {
	return _rl_unbind_command($_[0], _str2map($_[1]));
    } else {
	return _rl_unbind_command($_[0]);
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

#
#	for compatibility with Term::ReadLine::Perl
#
sub rl_filename_list {
    my ($text) = @_;
    return completion_matches($text, \&filename_completion_function);
}

#
#	History Library function wrappers
#
sub history_list () {
    my ($i, $history_base, $history_length, @d);
    $history_base   = $Attribs{history_base};
    $history_length = $Attribs{history_length};
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

sub get_history_event ( $$;$ ) {
    _get_history_event($_[0], $_[1], defined $_[2] ? ord $_[2] : 0);
}
