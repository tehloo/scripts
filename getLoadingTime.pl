#!/usr/bin/perl -w

use strict;
use warnings;
use Cwd 'abs_path';

###########################
# OPTIONS. you can give whatever you want.
#
	my $factorStart = 3;		# under 3, 3~4, 4~5....
	my $factorCount = 5;		# how many columns...
	my $ignoreCount = 1;		# ignore process data which has counted as given.

	
###########################
# variables.
#
	my @logfiles = ();			# list for MainLog files
	my $path = "logger";		# path to find MainLog files.
	my $error = 0;				# it will count errors from parsing phase.
	my $warning = 0;			# it will count warning from parsing and count for summary.
	my $lenLongestProc = 0;		# find longest process name for summary output format.

	my %hashProc = ();			# key = proc / data = array index.
	my @results = ();			# 2d array. 1st = count / 2nd = sum of duration / 3rd and further = count for each factors.

	my $totalCount = 0;			# it will count logs for "Displayed time"
	my $countAgain = 0;			# it will count every loading time counts to be compared with $totalCount.


###########################
# now we go.
#
	print "\n\n";
	getFilename();							# get file list for MainLog from 'logger' dir.
	getLines($_) foreach (@logfiles);		# read log lines from file array and parse each lines.
	putResults();							# make summary from gathered datas.

#
# job completed.
###########################


###########################
# sub functions.
#

# make summary from gathered datas.
sub putResults
{
	my @aSummary = ();
	my @aIgnored = ();
	
	# write titles.
	print "\n\n +++ RESULT +++ ( start factor : $factorStart / factor count : $factorCount / ignore : $ignoreCount )\n\n";
	print " Process"; print " " foreach(8..$lenLongestProc);
	print "  Cnt. Avg.\t";
	print "Under $factorStart\t";
	printf (" %d~%d\t",($_-1),$_) foreach ($factorStart+1..$factorStart+$factorCount-2);
	print "Over ".($factorStart+$factorCount-1)."\n\n";
	
	# write data.
	foreach my $proc ( sort keys %hashProc) {	
		if ($ignoreCount >= $results[ $hashProc{$proc} ][0] ) {		# IGNORE as given!
			push @aIgnored, $proc;
			$totalCount -= $results[ $hashProc{$proc} ][0];
			next;
		}
		
		my $checksum = 0;
		my $idx = 2;
		print " $proc ";
		print " " foreach (length($proc)..$lenLongestProc);		
		
		my $tCount = shift @{$results[ $hashProc{$proc} ]};
		my $tSum = shift @{$results[ $hashProc{$proc} ]};
		
		# start to write real data.
		print "$tCount\t"; $aSummary[0]+=$tCount;				# count.
		printf ("%.1f\t  ",$tSum/$tCount);$aSummary[1]+=$tSum;	# average.
		foreach (@{$results[ $hashProc{$proc} ]}) {				# ... and each datas.
			print " $_\t";
			$checksum+=$_;
			$aSummary[$idx]+=$_; $idx++;
		}
	
		#check count and sum
		print " (OK)\n" if ( $checksum == $tCount );
		$countAgain+=$checksum;
	}
	
	# show summary / SUM of count	
	print "\n";
	print " " foreach (0..$lenLongestProc);	
	print "  $aSummary[0]\t";
	printf ("%.1f\t  ",$aSummary[1]/$aSummary[0]);
	print "  $aSummary[$_]\t" foreach (2..$#aSummary);
	
	# show summary / AVG of displayed time.
	print "\n";
	print " " foreach (0..$lenLongestProc);	
	print "\t\t";
	printf ("  %.1f%%\t",$aSummary[$_]*100/$aSummary[0]) foreach (2..$#aSummary);
	
	# show ignored process
	if ($#aIgnored >= 0)	{
		print "\n - ".($#aIgnored+1)." processes ignored. (count)\n";
		printf (" %s (%d)\n", $_, $results[ $hashProc{$_} ][0])foreach (@aIgnored);
	}
		
	# check result data.
	print "\n\n";
	if ($countAgain == $totalCount)
	{	print " + $totalCount logs parsed and it all looks good!\n";	}
	else
	{	print " + Something's wrong!!! total parsed $totalCount. but result has $countAgain.\n";}
	print " + $warning warnings. you'd better to check log above.\n" if ($warning > 0); 
	print " + $error ERRORS! Something is wrong from PARSING phase.\n" if ($error > 0);	
}

# not used, but keep for reference.
sub pushNumberOrZero
{
	my $array = $_[0];
	my $value = defined($_[1])? $_[1]:0;	
	push @$array, $value;
}

# read log lines from file array and parse each lines.
# get process name and loading time from log, and push to pushToHash() func.
sub getLines
{
	open my $fh, "<", $_ or die "Cannot open file - $_";
	my $count =0;
	print " - Parsing $_ ...";

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
				print "\n $line -> $durSec sec.";
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


# receive process name and displayed time
# initialize and build hash for proc name and array for data.
sub pushToHash
{
	my $proc = $_[0];
	my $durSec = $_[1];
	
	# initialize results array as much as factorCount.
	if (!defined($hashProc{$proc}))
	{
		$hashProc{$proc} = $#results+1;		# add new process name as key, data is array index.
		$results[$hashProc{$proc}][$_] = 0 foreach (0..$factorCount+1)
	}

	# put count & sum to array 1st and 2nd
	$results[$hashProc{$proc}][0]++;			# add count as +1
	$results[$hashProc{$proc}][1] += $durSec;	# add loading time for sum
	
	# put count for each factors. started from 3rd.(index 2)
	foreach ($factorStart.. $factorStart+$factorCount-1)
	{
		my $idx=$_-$factorStart+2; 	# data will be set upon 2nd.
		
		# count under ...
		if ($_ == $factorStart)	{
			$results[$hashProc{$proc}][$idx] = ( $durSec < $_*1000 ) ?  ++$results[$hashProc{$proc}][$idx] : $results[$hashProc{$proc}][$idx];
		} 
		# count over ...
		elsif ($_ == $factorStart+$factorCount-1)	{
			$results[$hashProc{$proc}][$idx] = ( $durSec >= ($_-1)*1000 ) ?  ++$results[$hashProc{$proc}][$idx] : $results[$hashProc{$proc}][$idx];
		} 
		# count mid columns.
		else {
			$results[$hashProc{$proc}][$idx] = ( $durSec >= ($_-1)*1000 && $durSec < $_*1000 ) ?  ++$results[$hashProc{$proc}][$idx] : $results[$hashProc{$proc}][$idx];
		}
	}
	
	# find longest proc length for result format.
	$lenLongestProc = length($proc)>$lenLongestProc ? length($proc) : $lenLongestProc;
}

# build array only for MainLog.
sub getFilename 
{
	opendir(dirHandle, $path) || die "Failed opening.\n";
	my @files = readdir( dirHandle );	# get every files from dirHandle.
	closedir dirHandle;  # ²À ´ÝÀ¾...

	# get MainLog files and push to logfiles array.
	foreach (@files) {
		push @logfiles,abs_path($path."\\".$_) if ($_ =~ /main\.log.*/);
	}
}
