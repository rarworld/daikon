: # Use -*- Perl -*- without knowing its path
  eval 'exec perl -S -w $0 "$@"'
  if 0;
# whodini.pl -- Iteratively invoke ESC/Java on a source file until a fixed point is reached
# Jeremy Nimmer <jnimmer@lcs.mit.edu>

# Usage: whodini.pl [-d] annotations.txt-esc source.java [source2.java ...]

# Given a txt-esc file, and some number of (possibly-annotated) source
# files, produces ESC/Java output from processing the original source
# files, except uses as many of the annotations from the txt-esc file
# as possible to aid the verfication.  This script attempts to mimic
# the behavior of the Houdini tool from Compaq SRC.

use Carp;
use File::Copy;
use File::Path;
use POSIX qw(tmpnam);

# Algorithm for this script:
# 0 We are given a txt-esc file and some (possibly-annotated) source files
# 1 Read the txt file into memory, adding a nonce to the end of each invariant: "; // gensym"
# 2 Write the txt file (from memory) to a temp file
# 3 Copy the source files to a temp file
# 4 Merge the temp text file into the temp source files
# 5 Run ESC on the temp source files and slurp the results
# 6 Remove the two temporary files
# 7 Grep the results for "/*@ ...; // gensym */"
# 8 If any matching lines are found, remove them from the txt file in memory and go to step 2
# 9 Otherwise, dump the slurped output to stdout (with a little tweaking first) and exit

my $debug = 0;

my $tmpdir;
BEGIN {
    $tmpdir = tmpnam();
    die ("temporary filename already exists") if (-e $tmpdir);
    mkdir($tmpdir);
}
END {
    rmtree($tmpdir) if ($tmpdir);
}

sub debug {
    while ($debug && @_) {
	print shift, "\n";
    }
}

sub slurpfile {
    # returns the contents of the first argument (filename) as a list
    my $name = shift;
    open(F, $name) or die("Cannot open $name");
    my @result = <F>;
    close(F);
    return @result;
}

sub slurpfiles {
    # returns the contents of the arguments (filenames) as files
    my @files = @_;
    my @result = ();
    for my $file (@files) {
	my @slurp = slurpfile($file);
	push @result, \@slurp;
    }
    return @result;
}

my $gensym_counter = 0;
sub gensym {
    # returns some unique nonce
    my $result = $gensym_counter++;
    while (length($result) < 4) {
	$result = "0" . $result;
    }
    return $result;
}

sub notdir {
    # returns the non-dir part of the filenames
    my @names = @_;
    grep { s|^.*/||; } @names;
    return @names;
}

sub reltmp {
    # returns the non-dir part of the filname, with $tmpdir prepended
    my $name = shift;
    return $tmpdir . "/" . join(' ', notdir($name));
}

sub writetmp {
    # arg 1 is a filename (no slashes); args 2+ are the contents; returns the filename
    my $name = reltmp(scalar(shift));
    die ("temporary filename already exists") if (-e $name);
    open(F, ">$name");
    print F @_;
    close(F);
    return $name;
}

sub copytmp {
    # returns the filename of a fresh file, which is a copy of the argument (filename)
    my $arg = shift;
    my $name = reltmp($arg);
    die ("source filename '$arg' does not exist") unless (-e $arg);
    die ("temporary filename '$name' already exists") if (-e $name);
    copy($arg, $name);
    return $name;
}

# 0 We are given a txt-esc file and some (possibly-annotated) source files

if (($#ARGV >= 0) && ($ARGV[0] eq "-d")) {
    print STDERR "Debugging on\n";
    $debug = 1;
    shift @ARGV;
}
my $txtescfile = shift @ARGV;
my @sourcefiles = @ARGV;

{
    my $ok = defined($txtescfile) && (-f $txtescfile);
    $ok &&= scalar(@sourcefiles);
    for my $sourcefile (@sourcefiles) {
	$ok &&= (-f $sourcefile) && ($sourcefile =~ /\.java$/);
    }
    unless ($ok) {
	print STDERR "Usage: $0 annotations.txt-esc source.java [source2.java ...]\n";
	exit(1);
    }
}

# 1 Read the txt file into memory, adding a nonce to the end of each invariant: ";//nonce-gensym"

my @txtesc = slurpfile($txtescfile);
#@txtesc =
grep {
    my $nonce = "/*nonce-" . gensym() . "*/ ";
    # Skip over things we shouldn't touch; add a gensym to the rest
    unless (m/===========================================================================/
	    || m/\:\:\:(ENTER|EXIT|OBJECT|CLASS)/
	    || m/[V|v]ariables\:/)
    {
	s|^|$nonce|;
    }
} @txtesc;

print "Processing...";

# Iterative ("Houdini") looping
while (1) {
    # 2 Write the txt file (from memory) to a temp file
    $txtesctmp = writetmp($txtescfile, @txtesc);

    # 3 Copy the source files to a temp file
    my @sourcetmps;
    for my $sourcefile (@sourcefiles) {
	my $sourcetmp = copytmp($sourcefile);
	push @sourcetmps, $sourcetmp;
    }

    # 4 Merge the temp text file into the temp source files
    print STDERR `cd $tmpdir && merge-esc.pl -s $txtesctmp`;
    for my $sourcetmp (@sourcetmps) {
	unlink($sourcetmp);
	rename("$sourcetmp-escannotated", $sourcetmp);
    }

    # 5 Run ESC on the temp source files and slurp the results
    print ".";
    my $notdir_sourcetmp = join(" ", notdir(@sourcetmps));
    my @checked_sources = slurpfiles(@sourcetmps);
    my @escoutput = `cd $tmpdir && escjava $notdir_sourcetmp`;

    # 6 Remove the two temporary files
    unlink($txtesctmp);
    for my $sourcetmp (@sourcetmps) {
	unlink($sourcetmp);
    }

    # 7 Grep the results for "//@ ensures /*nonce-DDDD*/ ..." and extract the nonce
    my @failures = grep { m|/\*nonce-\d{4}\*/|; } @escoutput;
    debug("ESC reported", @failures);
    grep { s|^\s*//\@ \w+ /\*(nonce-\d{4})\*/ .*$|$1|s; } @failures;

    # 8 If any matching lines are found, remove them from the txt file in memory and go to step 2
    my $txtesc_changed = 0;
    for my $failure (@failures) {
	debug("Removing '$failure'");
	my $dec_check = $#txtesc;
	@txtesc = grep { !m/\Q$failure/ } @txtesc;
	if ($#txtesc < $dec_check) {
	    $txtesc_changed = 1;
	} else {
	    print STDERR "Did not find '$failure'\n";
	}
    }

    # 9 Otherwise, dump the slurped output to stdout (with a little tweaking first) and exit
    unless ($txtesc_changed) {
	print "\n";
	# Create a mapping from line number of the checked source to
	# the pre-whodini line number.
	my @map;
	my $count = 1;
	for my $checked_source_ref (@checked_sources) {
	    my @checked_source = @{$checked_source_ref};
	    my ($line_no, $orig_no);
	    for my $line (@checked_source) {
		$line_no++;
		$orig_no++ unless ($line =~ m|/\*nonce-\d{4}\*/|);
		$map[$count][$line_no] = $orig_no;
	    }
	    $count++;
	}
	# Replace line numbers in ESC output with the correct version
	$count = 0;
	grep {
	    if (m|^\w+ \.\.\.$|) {
		$count++;
	    }
	    s|(\.java\:)(\d+)(\:)|$1$map[$count][$2]$3|;
	    s|(Suggestion \[)(\d+)(,\d+\]\:)|$1$map[$count][$2]$3|;
	    s|(at )(\d+)(,\d+ in)|$1$map[$count][$2]$3|;
	    s|( line )(\d+)(, )|$1$map[$count][$2]$3|;
	} @escoutput;
	# Show ESC's output
	print @escoutput;
	exit;
    }
}
