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


my @aProc;
my @aPID;
my @aLru;
#my @aOomList;
my @aStrOom;


#hashes for processes...
my @aOrder;
#my %hOrder= ();
my %hProc= ();
my %hUid= ();
my %hAdjType= ();
my %hCurAdj= ();
my %hPss= ();
my %hLru= ();
my %hAdj= ();

my %hSumAdjType= ();


#my %proc_info=();
my $iPhase = 0;
my $numProc=0;
my $maxLengProc=0;
my $maxLengAdjType=0;
my $cntStack =0;
my $cntPERS = 0;

my $nPid=0;
my $TotalPssSum=0;

my $countPhase2=0;

while ( my $line = <$HF> )
{	
	
	if ($iPhase == 0)
	{
		if ( $line =~ /Processes in Current Activity Manager State:/ )	{
			plog ("Found start sign");		
		}
		
		elsif ($nPid==0 && $line =~ /\*APP\* UID (\d+) ProcessRecord{\S+\s(\d+):(\S+)\/(\d+)/ )
		{
			plog ("\n\t* process=$3\tUID=$1\tpid=$2\t/whatis?=$4");
			$nPid=int($2);
			
			push @aProc, $3;
			push @aPID, int($2);
			
			#$hProc{$nPid} = $3;
			
								
			$maxLengProc = ($maxLengProc < length($3) ? length($3) : $maxLengProc);
		}

		elsif ($nPid>0 && $line =~ /\s+lastActivityTime=(\S+) lruWeight=(\S+) (.*)/ )
		{
			plog ("\t\t lastActivityTime=$1 lruWeight=$2 / $3");		
			push @aLru, $2;
			
			$hLru{$nPid} = $2;
		}
		
	#	elsif ($nPid==1 && $line =~ /\s+oom: max=(\d+) hidden=(\d+) curRaw=(\d+) setRaw=(\d+) cur=(\d+) set=(\d+)/ )
		elsif ($nPid>0 && $line =~ /\s+oom: (.+)$/ )
		{
			plog ("\t\t oom=$1");
			push @aStrOom, $1 ;
			
			
			# int($1) if ( $1 =~ /cur=(\d+)/ );			
			$hCurAdj{$nPid} = int($1) if ( $1 =~ /cur=(\d+)/ );
			
			$nPid=0;
		}
		
		elsif ( $line =~ /Running processes \(most recent first\):/ )	{
			plog ("now we meet the stack list");
			$iPhase++;
		}
	}
	
#
#	NOW match with stack list!!
#
	elsif ($iPhase == 1)
	{
		if ( $line =~ /(\S{4}) #\s*(\d+): adj=(\S{3,5})\s*\/\S \S+ (\d+):(\S+)\/(\d+) (\S+)/ )
		{
			my $pid = int($4);
			$cntPERS++ if ( $1 eq "PERS" );
			if ( $2 == $cntStack ) {$cntStack++;}
			else { print "\nSomething wrong!\n"; last; }	
			
			push @aOrder, ($pid);
			$hAdjType{$pid} = $7;
			SumAdjType ($7);	
			$hProc{$pid} = $5;	
			$hUid{$pid} = $6;
			$hAdj{$pid} = $3;
			
			$maxLengAdjType = ($maxLengAdjType < length($7) ? length($7) : $maxLengAdjType);			
			
				
		}
		elsif ( $line =~ /PID mappings:/ ) {$iPhase++;};
		
	}
	
#
#	Grep PSSs
#	
	elsif ($iPhase == 2)
	{
		if ($nPid == 0 && $line =~ /\*\* MEMINFO in pid (\d+) \[(\S+)\] \*\*/ )
		{
			$countPhase2++;
			$nPid=$1;
		}
		elsif ( $nPid > 0 && $line =~ /\s+\(Pss\):\s+\S+\s+\S+\s+\S+\s+\S+\s+(\S+)/ )
		{
			$hPss{$nPid} = int($1);
			$TotalPssSum+=int($1);
			$nPid=0;
		}
	}
}

for ( my $idx = 0 ; $idx <= $#aLru ; $idx++ )
{
	plog ("$idx\t".$aLru[$idx]."\t".$aProc[$idx]."\t".$aPID[$idx]);
}

my $iOrder=1;

print "\n no  pid"; print " Process"; print " " foreach(6..$maxLengProc);
print " uid  Adjust type"; print " " foreach(11..$maxLengAdjType); print " cur  Pss  Lru      adj\n";
print " -- ---- "; print "-" foreach(0..$maxLengProc);
print " ----- "; print "-" foreach(0..$maxLengAdjType); print " --- ---- -------- -----\n";
	
while ( my $pid = shift @aOrder )
{			
	my $strProc = defined $hProc{$pid} ? $hProc{$pid} : "";
	
	printf (" %2d %4d %s",$iOrder++,$pid, $strProc);
	print " " foreach(length($strProc)..$maxLengProc);
	printf (" %5d %s",$hUid{$pid},$hAdjType{$pid});
	print " " foreach(length($hAdjType{$pid})..$maxLengAdjType);	
	defined($hCurAdj{$pid}) ? printf " %2d",$hCurAdj{$pid}: print "  -";
	defined($hPss{$pid}) ? printf " %5d",$hPss{$pid}: print "     -";
	defined($hLru{$pid}) ? printf " %8d",$hLru{$pid}: print "     -   ";	
	defined($hAdj{$pid}) ? printf " %s",$hAdj{$pid}: print "     -";
	
	print "\n";
}

print "\n ".($#aProc+1)." processes found in dumpsys / $cntStack processes found in Stack. ( $cntPERS persistent processes )\n\n";

for my $type ( keys %hSumAdjType )
{
	my $PssSum=0;
	
	for my $pid ( keys %hAdjType )
	{	
		if ( $hAdjType{$pid} eq $type )
		{
			$PssSum+=$hPss{$pid} if defined($hPss{$pid});	
		}
	}	
	print " $type "; 
	print " " foreach(length($type)..$maxLengAdjType);	
	print ": $PssSum kB ($hSumAdjType{$type})\n";
}

my %SumAdj = ();
my $adj;
for $adj ( keys %hAdj )
{	
	my $pid = $hAdj{$adj};
	if (defined($SumAdj{$pid}))
	{	 
		$SumAdj{$pid}++;
	}
	else { 
		$SumAdj{$pid}=1; 
	}
}

print "\n";

for $adj ( keys %SumAdj )
{
	my $PssSum = 0;
	for my $pid ( keys %hAdj )
	{
		if ( $hAdj{$pid} eq $adj )
		{
			$PssSum += $hPss{$pid} if defined($hPss{$pid});
		}
	}
	print " $adj\t: $PssSum kB ($SumAdj{$adj})\n";
}

printf "\n total Pss = %.2f MB (%d kB)\n", ($TotalPssSum/1024), $TotalPssSum;
	
sub SumAdjType 
{
	plog ("add key as $_[0] and value + 1");	
	if (defined ($hSumAdjType{$_[0]}))
	{$hSumAdjType{$_[0]}++;}
	else	
	{ $hSumAdjType{$_[0]}=1;}
}

sub plog
{
	if ( $bDebugging > 0 ) {	
		print $_[0]."\n";
	}
	return;
}

