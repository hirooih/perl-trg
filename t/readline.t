# -*- perl -*-
#	readline.t - Test script for Term::ReadLine:GNU
#
#	$Id: readline.t,v 1.16 1997-03-17 17:39:44 hayashi Exp $
#
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl t/readline.t'

BEGIN {print "1..14\n";}
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
# test Attribs method

my $attribs = $term->Attribs;
print defined $attribs ? "ok 5\n" : "not ok 5\n";

########################################################################
# test tied variable

# Version 2.0 is NOT supported.
print $attribs->{library_version} > 2.0 ? "ok 6\n" : "not ok 6\n";

########################################################################
# test key binding functions

my %TYPE = (0 => 'Function', 1 => 'Keymap', 2 => 'Macro');

# sample custom function (reverse whole line)
sub reverse_line {
    my($count, $key) = @_;	# ignored in this sample function
    $attribs->{line_buffer} = reverse $attribs->{line_buffer};
}

# using method
$term->AddDefun('reverse-line', \&reverse_line, ord "\ct");
$term->BindKey(ord "\ct", 'reverse-line', 'emacs-ctlx');
$term->ParseAndBind('"\C-xt": reverse-line');

sub display_readline_version {
    my($count, $key) = @_;	# ignored in this sample function
    print $OUT "GNU Readline Library version: $attribs->{library_version}\n";
# rl_message() does not work.
#    $term->message("GNU Readline Library version: $$term->library_version\n");
    $term->on_new_line();
}
# using function
$term->add_defun('display-readline-version', \&display_readline_version);
$term->bind_key(ord "\cv", 'display-readline-version', 'emacs-ctlx');
$term->parse_and_bind('"\C-xv": display-readline-version');

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

print $OUT "\n";
foreach ("\co", "\ct", "\cx",
	 "\cx\ct", "\cxt", "\cx\cv", "\cxv",
	 "\e?f", "\e?v", "\e?i") {
    my ($p, $type) = $term->function_of_keyseq($_);
    print $OUT (toprint($_));
    (print "\n", next) unless defined $type;
    print $OUT ": $TYPE{$type},\t";
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
$term->StifleHistory(5);
$term->{DoExpand} = 1;
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
$term->UnbindKey(ord "\ct");
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

@{$term->{CompletionWordList}} =
    qw(list of words which you want to use for completion);
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
# test rl_getc_function and rl_getc()
sub uppercase {
    my $FILE = $attribs->{instream};
    return ord uc chr $term->getc($FILE);
#    return ord uc chr $term->getc($attribs->{instream}); # Why does this cause error?
}

$attribs->{getc_function} = \&uppercase;
$term->readline("convert to uppercase>");
$attribs->{getc_function} = undef;

print "ok 11\n";

########################################################################
# test rl_startup_hook

sub insert_string { $term->insert_text('insert text'); };
$attribs->{startup_hook} = \&insert_string;
$term->readline("rl_startup_hook test>");
$attribs->{startup_hook} = undef;

print "ok 12\n";

########################################################################
# test WriteHistory(), ReadHistory()
#short_cut:
my @list_write = $term->GetHistory();
$term->WriteHistory(".history_test") || warn "error at write_history: $!\n";
$term->SetHistory();
$term->ReadHistory(".history_test") || warn "error at read_history: $!\n";
my @list_read = $term->GetHistory();
print cmp_list(\@list_write, \@list_read) ? "ok 13\n" : "not ok 13\n";

########################################################################
# test SetHistory(), GetHistory()

my @list_set = qw(one two three);
$term->SetHistory(@list_set);
my @list_get = $term->GetHistory();
print cmp_list(\@list_set, \@list_get) ? "ok 14\n" : "not ok 14\n";

end_of_test:

exit 0;
