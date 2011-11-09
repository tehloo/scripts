#!/usr/bin/perl -w

use strict;
use warnings;
use POSIX 'isatty';

if ( ! @ARGV && isatty(*STDIN) ) {
    die "usage: ...";
}

my $enableLog = 0;
my $HF;

if (@ARGV)
{
	open ($HF, $ARGV[0]) if ( -f $ARGV[0]  );
	print "File Opened.\n";
	
}
else {$HF = \*STDIN;}

my $bReadyGetLru=0;
my @aProc;
my @aPID;
my @aLru;
my %proc_info=();

while ( my $line = <$HF> )
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

print $#aLru."\n";
print $#aProc."\n";
print $#aPID."\n";


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

my $idx;

for ( $idx = 0 ; $idx <= $#aLru ; $idx++ )
{
	print "$idx\t".$aLru[$idx]."\t".$aProc[$idx]."\t".$aPID[$idx]."\n";
}

print "\n ".($#aProc+1)." process found.\n\n";

my $rank=1;
my $highLru=-32768;
my $highIdx=0;

#for ( $rank = 0 ; $rank <= $#aLru ; $rank++ )
=cut
while ( $#aLru )
{
	for ( $idx = 0; $idx <= $#aLru ; $idx++ )
	{
		if ( $aLru[$idx] > $highLru )
		{
			$highLru = $aLru[$idx];
			$highIdx = $idx;			
		}
	}	
	print " ".$rank++."\t".$aPID[$highIdx]."\t".$highLru." ".$aProc[$highIdx]."\n";
	splice(@aLru, $highIdx, 1);	
	splice(@aProc, $highIdx, 1);	
	splice(@aPID, $highIdx, 1);	
	$highLru=0;
}



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

