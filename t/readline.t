# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN {print "1..8\n";}
END {print "not ok 1\n" unless $loaded;}

$^W = 1;			# perl -w
use strict;
use vars qw($loaded);
use Term::ReadLine qw(:custom_completion);
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

my $term = new Term::ReadLine 'ReadLineTest';
print defined $term ? "ok 2\n" : "not ok 2\n";

my $OUT = $term->OUT || \*STDOUT;

print $term->ReadLine eq 'Term::ReadLine::Gnu' ? "ok 3\n" : "not ok 3\n";

my %features = %{ $term->Features };
if (%features) {
    my @f = %features;
#    print "Features present: @f\n";
    print "ok 4\n";
} else {
    print "No additional features present.\n";
    print "not ok 4\n";
}

########################################################################
# test history expansion
print "# history expansion test\n";
print "# quit by EOF (\\C-d)\n";
$term->MinLine(1);
$term->StifleHistory(10);
$term->{DoExpand} = 1;
my ($nline, $line);
for ($nline = 0;
     defined($line = $term->readline("$nline>"));
     $nline++) {
    print "<<$line>>\n";
}
print "\nok 5\n";

########################################################################
# test custom completion function

$term->readline("filename completion (default)>", "this is default string");

$rl_completion_entry_function = 'username';
$term->readline("username completion>");

@completion_word_list = qw(list of words which you want to use for completion);
$rl_completion_entry_function = \&list_completion_function;
$term->readline("custom completion>");

$rl_completion_entry_function = 'filename';
$term->readline("filename completion>");

sub sample_completion {
    my ($text, $line, $start, $end) = @_;
#    print "\n[$text:$line:$start:$end]\n";
    # If first word then username completion, else filename completion
    if (substr($line, 0, $start) =~ /^\s*$/) {
	return completion_matches($text, 'username');
    } else {
	return ();
    }
}

$rl_attempted_completion_function = \&sample_completion;
$term->readline("username filename completion>");
$rl_attempted_completion_function = undef;

print "ok 6\n";
########################################################################
# test WriteHistory(), ReadHistory()
my @list_write = $term->GetHistory();
$term->WriteHistory(".history_test") || warn "error at write_history: $!\n";
$term->SetHistory();
$term->ReadHistory(".history_test") || warn "error at read_history: $!\n";
my @list_read = $term->GetHistory();
print equal_list(\@list_write, \@list_read) ? "ok 7\n" : "not ok 7\n";

########################################################################
# test SetHistory(), GetHistory()
my @list_set = qw(one two three);
$term->SetHistory(@list_set);
my @list_get = $term->GetHistory();
print equal_list(\@list_set, \@list_get) ? "ok 8\n" : "not ok 8\n";

sub equal_list {
    ($a, $b) = @_;
    my @a = @$a;
    my @b = @$b;
    return undef if $#a ne $#b;
    for (0..$#a) {
	return undef if $a[$_] ne $b[$_];
    }
    return 1;
}

exit 0;
