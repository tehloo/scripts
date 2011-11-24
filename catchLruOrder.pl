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

my $bReadyGetLru=0;
my @aProc;
my @aPID;
my @aLru;
#my @aOomList;
my @aStrOom;

my %proc_info=();
my $numProc=0;
my $maxLengProc=0;

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
=cut
		plog ("\t\t max=$1 hidden=$2 curRaw=$3 setRaw=$4 cur=$5 set=$6");
		my @aOomItem;
		
		push @aOomItem, $1;
		push @aOomItem, $2;
		push @aOomItem, $3;
		push @aOomItem, $4;
		push @aOomItem, $5;
		push @aOomItem, $6;
		
		push @aOomList, @aOomItem;
=cut	
		push @aStrOom, $1 ;
		$bReadyGetLru=0;
	}

}

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
	plog ("$idx\t".$aLru[$idx]."\t".$aProc[$idx]."\t".$aPID[$idx]);
}

print "\n ".($#aProc+1)." process found.\n\n";

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
	if ( $bDebugging > 0 ) {	
		print $_[0]."\n";
	}
	return;
}

