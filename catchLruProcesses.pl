#!/usr/bin/perl -w

use strict;
use warnings;
use POSIX 'isatty';

if ( ! @ARGV && isatty(*STDIN) ) {
    die "usage: ...";
}

my $bDebugging = 0;
my $HF;

if (@ARGV)
{
	open ($HF, $ARGV[0]) if ( -f $ARGV[0]  );
	plog ("File Opened. $ARGV[0]\n");
}
else {$HF = \*STDIN;}

my $bReadyGetLru=1;
my @aProc;
my @aPID;
my @aLru;
#my @aOomList;
my @aStrOom;

my %proc_info=();
my $numProc=0;
my $maxLengProc=0;
my $cntStack =-1;
my $cntPERS = 0;

while ( my $line = <$HF> )
{	
	if ($cntStack < 0)
	{
		if ( $line =~ /Processes in Current Activity Manager State:/ )	{
			plog ("Found start sign");		
		}
		
		elsif ($line =~ /\*APP\* UID (\d+) ProcessRecord{\S+\s(\d+):(\S+)\/(\d+)/ )
		{
			plog ("\n\t* process=$3\tUID=$1\tpid=$2\t/whatis?=$4");
			$bReadyGetLru=1;
			push @aProc, $3;
			push @aPID, int($2);
			
			$maxLengProc = ($maxLengProc < length($3) ? length($3) : $maxLengProc);
		}

		elsif ($bReadyGetLru==1 && $line =~ /\s+lastActivityTime=(\S+) lruWeight=(\S+) (.*)/ )
		{
			plog ("\t\t lastActivityTime=$1 lruWeight=$2 / $3");		
			push @aLru, $2;		
		}
		
	#	elsif ($bReadyGetLru==1 && $line =~ /\s+oom: max=(\d+) hidden=(\d+) curRaw=(\d+) setRaw=(\d+) cur=(\d+) set=(\d+)/ )
		elsif ($bReadyGetLru==1 && $line =~ /\s+oom: (.+)$/ )
		{
			plog ("\t\t oom=$1");
			push @aStrOom, $1 ;
			$bReadyGetLru=0;
		}
		
		elsif ( $line =~ /Running processes \(most recent first\):/ )	{
			plog ("now we meet the stack list");
			$cntStack++;
			print "\n";
			print " --  ----   "; print "-" foreach(0..$maxLengProc);
			print " ----- --------------------- ---";print "\n";
			
		}
	}
#
#	NOW match with stack list!!
#
	else
	{
		if ( $line =~ /(\S{4}) #\s*(\d+): adj=\S{3,5}\s*\/\S \S+ (\d+):(\S+)\/(\d+) (\S+)/ )
		{
			printf (" %2d %5d   %s",$2,$3,$4);
			print " " foreach(length($4)..$maxLengProc);
			printf (" %5d %s", $5, $6);
			print " " foreach(length($6)..21);
			# find current adjustment.
			
			for (my $i=0; $i <= $#aPID; $i++ ) 
			{ 
				if ($aPID[$i] == int($3)) { 
				#print $aStrOom[$i]; 
				printf ("%3d",$1) if ( $aStrOom[$i] =~ /cur=(\d+)/ );
				last; }
			}
			print "\n";
			
			$cntPERS++ if ( $1 eq "PERS" );
			if ( $2 == $cntStack ) {$cntStack++;}
			else { print "\nSomething wrong!\n"; last; }		
			
		}
	}
}

for ( my $idx = 0 ; $idx <= $#aLru ; $idx++ )
{
	plog ("$idx\t".$aLru[$idx]."\t".$aProc[$idx]."\t".$aPID[$idx]);
}

print "\n ".($#aProc+1)." processes found in dumpsys / $cntStack processes found in Stack. ( $cntPERS persistent processes )\n\n";

=cut
if ($#aLru != $#aProc || $#aProc != $#aPID)
{
	print "\n ERROR! array number mismatch!!! lru=".$#aLru."/ proc=".$#aProc."/ PID=".$#aPID."\n";
	die;
}

if ($#aLru == -1)
{
	print "\n no matches found!!!\n";
	die;
}








my $rank=1;
my $highLru=-99999;
my $highIdx=0;

#for ( $rank = 0 ; $rank <= $#aLru ; $rank++ )
print " rank\t PID\t LRU\t  Process name\n";
print " ----\t----\t-------\t ------------------------------------\n";
while ( $#aLru >= 0 )
{
	for ( $idx = 0; $idx <= $#aLru ; $idx++ )
	{
		if ( $aLru[$idx] > $highLru )
		{
			$highLru = $aLru[$idx];
			$highIdx = $idx;			
		}
	}	
	print " ".$rank++."\t".$aPID[$highIdx]."\t".$highLru;
	print "\t" if ( $highLru < 10000000 );
	print " ".$aProc[$highIdx];
	my $iBlank = $maxLengProc - length($aProc[$highIdx]);
	print " " while ( $iBlank-- > 0);
#	print "\t".$aOomList[$highIdx];	
	print " ".$aStrOom[$highIdx];
	print "\n";
	
	splice(@aLru, $highIdx, 1);	
	splice(@aProc, $highIdx, 1);	
	splice(@aPID, $highIdx, 1);	
	splice(@aStrOom, $highIdx, 1);	
	$highLru=-99999;
}
print " ----\t----\t-------\t ------------------------------------\n";




while ( my $lru = shift(@sortLru))
{
	print $index++.".";
	my $iLru = $#aLru+1;	
	while ($iLru--)
	{
		if ($lru == $aLru[$iLru]) 
		{
			my $temp = 8 - length($lru);
			print " "; while ($temp--) {print " ";}			
			print $lru." : ".$aProc[$iLru]."\n";		
			last;
		}
	}
}
=cut

sub plog
{
	if ( $bDebugging > 0 ) {	
		print $_[0]."\n";
	}
	return;
}

