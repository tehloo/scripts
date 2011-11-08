#!/usr/bin/perl -w

use strict;
use warnings;

my $enableLog = 0;


plog ("File opened");
my $bReadyGetLru=0;
my @aProc;
my @aPID;
my @aLru;
my %proc_info=();

while (my $line = <STDIN> )
{	
		
	if ( $line =~ /Processes in Current Activity Manager State:/ )	{
		plog ("Found start sign");		
	}
	
	elsif ($line =~ /\*APP\* UID (\d+) ProcessRecord{\S+\s(\d+):(\S+)\/(\d+)/ )
	{
		plog ("\n\t* process=$3\tUID=$1\tpid=$2\t/whatis?=$4");
		$bReadyGetLru=1;
		push @aProc, $3;
		push @aPID, $2;
	}
	
	elsif ($bReadyGetLru==1 && $line =~ /\s+oom: max=(\d+) hidden=(\d+) curRaw=(\d+) setRaw=(\d+) cur=(\d+) set=(\d+)/ )
	{
		plog ("\t\t max=$1 hidden=$2 curRaw=$3 setRaw=$4 cur=$5 set=$6");		
	}
	
	elsif ($bReadyGetLru==1 && $line =~ /\s+lastActivityTime=(\S+) lruWeight=(\S+) (.*)/ )
	{
		plog ("\t\t lastActivityTime=$1 lruWeight=$2 / $3");		
		push @aLru, $2;
		$bReadyGetLru=0;
	}
}


if ($#aLru != $#aProc || $#aProc != $#aPID )
{
	print "\n ERROR! array number mismatch!!! lru=".$#aLru."/ proc=".$#aProc."/ PID=".$#aPID."\n"
}



my $idx;
my $idx_2;
my $tempLru;
my $tempPID;
my $tempProc;

for ( $idx = 0 ; $idx <= $#aLru ; $idx++ )
{
	print "$idx\t".$aLru[$idx]."\t".$aProc[$idx]."\t".$aPID[$idx]."\n";
}

print "\n ".($#aProc+1)." process found.\n\n";

for ( $idx = 0 ; $idx <= $#aLru ; $idx++ )
{
	for ( $idx_2 = $idx; $idx_2 <= $#aLru ; $idx_2++ )
	{
		if ( $aLru[$idx] < $aLru[$idx_2] ) 
		{
			$tempLru = $aLru[$idx];
			$tempPID = $aPID[$idx];
			$tempProc = $aProc[$idx];
			
			$aLru[$idx] = $aLru[$idx_2];
			$aPID[$idx] = $aPID[$idx_2];
			$aProc[$idx] = $aProc[$idx_2];
			
			$aLru[$idx_2] = $tempLru;
			$aPID[$idx_2] = $tempPID;
			$aProc[$idx_2] = $tempProc;		
		}
	}
	#print $itemLRU."\n";
	$idx++;
}

for ( $idx = 0 ; $idx <= $#aLru ; $idx++ )
{
	print "$idx\t".$aLru[$idx]."\t".$aProc[$idx]."\t".$aPID[$idx]."\n";
}

=cut
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
	if ( $enableLog > 0 ) {	
		print $_[0]."\n";
	}
	return;
}

