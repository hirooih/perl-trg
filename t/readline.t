# -*- perl -*-
#	readline.t - Test script for Term::ReadLine:GNU
#
#	$Id: readline.t,v 1.13 1997-02-04 16:22:42 hayashi Exp $
#
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl t/readline.t'

BEGIN {print "1..13\n";}
END {print "not ok 1\n" unless $loaded;}

$^W = 1;			# perl -w
use strict;
use vars qw($loaded);
if ($] > 5.002) {
    use ExtUtils::testlib;
} else {
    use lib './blib';
}
use Term::ReadLine;
use Term::ReadLine::Gnu qw(:all);

$loaded = 1;
print "ok 1\n";

#goto end_of_test;

########################################################################
sub cmp_list {
    ($a, $b) = @_;
    my @a = @$a;
    my @b = @$b;
    return undef if $#a ne $#b;
    for (0..$#a) {
	return undef if $a[$_] ne $b[$_];
    }
    return 1;
}

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
# test tied variable

# Version 2.0 is NOT supported.
print $rl_library_version > 2.0 ? "ok 5\n" : "not ok 5\n";

########################################################################
# test key binding functions

my %TYPE = (0 => 'Function', 1 => 'Keymap', 2 => 'Macro');

# sample custom function (reverse whole line)
sub reverse_line {
    my($count, $key) = @_;	# ignored in this sample function
    $rl_line_buffer = reverse $rl_line_buffer;
}

# using method
$term->AddDefun('reverse-line', \&reverse_line, ord "\ct");
$term->BindKey(ord "\ct", 'reverse-line', 'emacs-ctlx');
$term->ParseAndBind('"\C-xt": reverse-line');

sub display_readline_version {
    my($count, $key) = @_;	# ignored in this sample function
    print $OUT "GNU Readline Library version: $rl_library_version\n";
# rl_message() does not work.
#    rl_message("GNU Readline Library version: $rl_library_version\n");
    rl_on_new_line();
}
# using function
rl_add_defun('display-readline-version', \&display_readline_version);
rl_bind_key(ord "\cv", 'display-readline-version', 'emacs-ctlx');
rl_parse_and_bind('"\C-xv": display-readline-version');

# make original map
my $helpmap = rl_make_bare_keymap();
rl_bind_key(ord "f", 'dump-functions', $helpmap);
rl_generic_bind(ISKMAP, "\e?", $helpmap);
rl_bind_key(ord "v", 'dump-variables', $helpmap);
# documented but not defined by GNU Readline
#rl_generic_bind(ISFUNC, "\e?m", 'dump-macros');

# bind macro
rl_generic_bind(ISMACR, "\e?i", "\ca[insert text from beginning of line]");

# convert control charactors to printable charactors (ex. "\cx" -> '\C-x')
sub toprint {
    join('',map{ord($_)<32 ? '\C-'.lc(chr(ord($_)+64)) : $_}(split('',$_[0])));
}

print $OUT "\n";
foreach ("\co", "\ct", "\cx",
	 "\cx\ct", "\cxt", "\cx\cv", "\cxv",
	 "\e?f", "\e?v", "\e?i") {
    my ($p, $type) = rl_function_of_keyseq($_);
    print $OUT (toprint($_));
    (print "\n", next) unless defined $type;
    print $OUT ": $TYPE{$type},\t";
    if    ($type == ISFUNC) { print $OUT (rl_get_function_name($p)); }
    elsif ($type == ISKMAP) { print $OUT (rl_get_keymap_name($p)); }
    elsif ($type == ISMACR) { print $OUT (toprint($p)); }
    else { print $OUT "Error Illegal type value"; }
    print $OUT "\n";
}
my @keyseqs = rl_invoking_keyseqs('reverse-line');
print $OUT "reverse-line is bound to ", join(', ',@keyseqs), "\n";

print "ok 6\n";

########################################################################
# test history expansion

# goto short_cut;
# goto end_of_test;

print $OUT "\n# history expansion test\n";
print $OUT "# quit by EOF (\\C-d)\n";
$term->MinLine(1);
$term->StifleHistory(5);
$term->{DoExpand} = 1;
my ($nline, $line);
for ($nline = 0;
     defined($line = $term->readline("$nline>"));
     $nline++) {
    print $OUT "<<$line>>\n";
}
print $OUT "\n";
print "ok 7\n";

########################################################################
# test key unbinding functions

print $OUT "unbind \\C-t and \\C-xt\n";
$term->UnbindKey(ord "\ct");
rl_unbind_key(ord "t", 'emacs-ctlx');

@keyseqs = rl_invoking_keyseqs('reverse-line');
print $OUT "reverse-line is bound to ", join(', ',@keyseqs), "\n";
print "ok 8\n";

########################################################################
# test custom completion function

$term->readline("filename completion (default)>", "this is default string");

$rl_completion_entry_function = \&username_completion_function;
$term->readline("username completion>");

@{$term->{CompletionWordList}} =
    qw(list of words which you want to use for completion);
$rl_completion_entry_function = \&list_completion_function;
$term->readline("list completion>");

$rl_completion_entry_function = \&filename_completion_function;
$term->readline("filename completion>");

sub sample_completion {
    my ($text, $line, $start, $end) = @_;
    # If first word then username completion, else filename completion
    if (substr($line, 0, $start) =~ /^\s*$/) {
	return completion_matches($text, \&list_completion_function);
    } else {
	return ();
    }
}

$rl_attempted_completion_function = \&sample_completion;
$term->readline("list & filename completion>");
$rl_attempted_completion_function = undef;

print "ok 9\n";

########################################################################
# test rl_getc_function and rl_getc()
sub uppercase {
    my $FILE = $rl_instream;
    return ord uc chr rl_getc($FILE);
#    return ord uc chr rl_getc($rl_instream); # Why does this cause error?
}

$term->StoreVar('rl_getc_function', \&uppercase);
$term->readline("convert to uppercase>");
$term->StoreVar('rl_getc_function', undef);

print "ok 10\n";

########################################################################
# test rl_startup_hook

sub insert_string { rl_insert_text('insert text'); };
$term->StoreVar('rl_startup_hook', \&insert_string);
$term->readline("rl_startup_hook test>");
$term->StoreVar('rl_startup_hook', undef);

print "ok 11\n";

########################################################################
# test WriteHistory(), ReadHistory()

my @list_write = $term->GetHistory();
$term->WriteHistory(".history_test") || warn "error at write_history: $!\n";
$term->SetHistory();
$term->ReadHistory(".history_test") || warn "error at read_history: $!\n";
my @list_read = $term->GetHistory();
print cmp_list(\@list_write, \@list_read) ? "ok 12\n" : "not ok 12\n";

########################################################################
# test SetHistory(), GetHistory()

my @list_set = qw(one two three);
$term->SetHistory(@list_set);
my @list_get = $term->GetHistory();
print cmp_list(\@list_set, \@list_get) ? "ok 13\n" : "not ok 13\n";

end_of_test:

exit 0;
