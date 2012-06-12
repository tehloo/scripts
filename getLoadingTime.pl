#!/usr/bin/perl -w

use strict;
use warnings;
use POSIX 'isatty';
use Cwd 'abs_path';

my $bDebug = 1;
my @logfiles = ();
my $path = "logger";
my $error = 0;
my $warning = 0;
my $lenLongestProc = 0;

my %LoadingSum = ();	# sum of loading time.
my %LoadingCount = ();	# count of fork for each processes.
my %Under3 = ();
my %Over3 = ();

my $factorStart = 3;	# under 3, 3~4, 4~5....
my $factorCount = 5;	# how many columns...
my %hashProc = ();			# proc & array index.
my @results = ();		# 2d array;

my $totalCount = 0;
my $countAgain = 0;

###########################
# now we go.
###########################

getFilename();
#print "@logfiles";
getLines($_) foreach (@logfiles);
putResults();


###########################
# job completed.
###########################
sub putResults
{
	print "\n";
	
	foreach $_ ( keys %LoadingSum) {
		my @items = ();
		pushNumberOrZero(\@items, $LoadingCount{$_});
		pushNumberOrZero(\@items, $LoadingSum{$_}/$LoadingCount{$_});
		pushNumberOrZero(\@items, $Under3{$_});
		pushNumberOrZero(\@items, $Over3{$_});
		
		print "$_ : ";
		print " " foreach (length($_)..$lenLongestProc);
		print shift @items;
		printf ("\t%.1f\t",shift @items);
		print "$_\t" foreach (@items);
		print "\n";
		$countAgain+=$LoadingCount{$_};
	}

#### prefer below then aboves.

	print "\nrenew!!!\n";
	foreach $_ ( keys %hashProc) {
		print "$_ : ";
		print " " foreach (length($_)..$lenLongestProc);
		
		my $tCount = shift @{$results[ $hashProc{$_} ]};
		print "$tCount\t";
		printf ("%.1f\t",(shift @{$results[ $hashProc{$_} ]})/$tCount);
		print "$_\t" foreach @{$results[ $hashProc{$_} ]};
		print "\n";
	}
	
	print "\n$countAgain | $totalCount\n";
}

sub pushNumberOrZero
{
	my $array = $_[0];
	my $value = defined($_[1])? $_[1]:0;	
	push @$array, $value;
}

sub getLines
{
	open my $fh, "<", $_ or die "Cannot open file - $_";
	my $count =0;
	print "Parsing $_ ...";

	while (my $line = <$fh> )
	{
		if ( $line =~ /.*(\d+:\d+:\d+\.\d+)\sI\/Activity.*:\sDisplayed\s(\S+):\s(\+\S+ms)/ )
		{
			#print $1."-".$2." ".$3."\n";
			my $proc = $2;
			my $durSec = 0;
			if ( $3 =~ /\+(\d+)s(\d+)ms/ )
			{
				$durSec = int($1)*1000 + int($2);
			}
			elsif ( $3 =~ /\+(\d+)ms/ )
			{
				$durSec = int($1);				
			}
			elsif ( $line =~ /total\s\+(\d+)s(\d+)ms/ )
			{
				$durSec = int($1)*1000 + int($2);
				print "\n$line -> $durSec sec.\n";
				$warning++;
			}
			else 
			{			
				print "What should I do??? - $line\n";
				$error++;
			}
			$count++;
			
			pushToHash ($proc, $durSec);
		}
	}
	print "\tFound $count lines.\n";
	close $fh;
	$totalCount += $count;
}

sub pushToHash
{
	my $proc = $_[0];
	my $durSec = $_[1];
	
	if (!defined($hashProc{$proc}))
	{
		print "\nnew array... ".$#results;
		$hashProc{$proc} = $#results+1;
		$results[$hashProc{$proc}][$_] = 0 foreach (0..$factorCount+2)
	}

	$results[$hashProc{$proc}][0]++;
	$results[$hashProc{$proc}][1] += $durSec;
	
	foreach ($factorStart.. $factorStart+$factorCount-1)
	{
		my $idx=$_-$factorStart+2; 	# data will be set upon 2nd.
		if ($_ == $factorStart)	{
			$results[$hashProc{$proc}][$idx] = ( $durSec < $_*1000 ) ?  ++$results[$hashProc{$proc}][$idx] : $results[$hashProc{$proc}][$idx];
		} elsif ($_ == $factorStart+$factorCount-1)	{
			$results[$hashProc{$proc}][$idx] = ( $durSec >= ($_-1)*1000 ) ?  ++$results[$hashProc{$proc}][$idx] : $results[$hashProc{$proc}][$idx];
		} else {
			$results[$hashProc{$proc}][$idx] = ( $durSec >= ($_-1)*1000 && $durSec < $_*1000 ) ?  ++$results[$hashProc{$proc}][$idx] : $results[$hashProc{$proc}][$idx];
		}
	}
	
	
	
	if ( defined $LoadingSum{$proc} ) {
		$LoadingSum{$proc} += $durSec;
	} else {
		$LoadingSum{$proc} = $durSec;
	}
	
	if ( defined $LoadingCount{$proc} ) {
		$LoadingCount{$proc}++;
	} else {
		$LoadingCount{$proc} = 1;
	}
	
	if ($durSec < 3000 ) {
		if (defined ($Under3{$proc}))	{
			$Under3{$proc}++;
		}
		else	{
			$Under3{$proc} = 1;
		}
	}
	elsif ($durSec >= 3000) {
		if (defined ($Over3{$proc}))	{
			$Over3{$proc}++;
		}
		else	{
			$Over3{$proc} = 1;
		}	
	}
	
	$lenLongestProc = length($proc)>$lenLongestProc ? length($proc) : $lenLongestProc;
}

sub getFilename 
{
	opendir(dirHandle, $path) || die "Failed opening.\n";
	my @files = readdir( dirHandle );
	closedir dirHandle;  # ²À ´ÝÀ¾...

	foreach (@files)
	{
		push @logfiles,abs_path($path."\\".$_) if ($_ =~ /main\.log.*/);
	}
	
	#print "@logfiles";
}