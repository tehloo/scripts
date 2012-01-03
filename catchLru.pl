#!/usr/bin/perl -w

use strict;
use warnings;
use POSIX 'isatty';
use Scalar::Util qw(looks_like_number);

if ( ! @ARGV && isatty(*STDIN) ) {
    die "usage: ...";
}

my $bDebugging = 1;
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
my %hLastAct = ();

my %hSumAdjType= ();


#my %proc_info=();
my $iPhase = -2;
my $numProc=0;
my $maxLengProc=0;
my $maxLengAdjType=0;
my $cntStack =0;
my $cntPERS = 0;

my $nPid=0;
my $TotalPssSum=0;

my $countPhase2=0;
my $bIsICS;

my $svcProc = "";
my $svcPID = -1;
my %hSvcProc = ();

while ( my $line = <$HF> )
{
	if ($iPhase == -2 )
	{
		if ( $line =~ /Services in Current Activity Manager State:/ )	{
			plog ("Found service state");
			$iPhase = -1;
		}
	}
	elsif ($iPhase == -1 )
	{	
		if ( $line =~ /app=ProcessRecord{\S+ (\d+):(\S+)\/\d+}/)
		{
			plog (" + meet svc $1 : $2");
			$svcPID = $1;
			$svcProc = $2;
		}
		elsif ( $line =~ /\s{6}\* Client AppBindRecord{\S+ ProcessRecord{\S+ (\d+):(\S+)\/\d+}}/ )
		{
			plog ("  -> grep binded svc $1:$2 is client of $svcProc");
			$hSvcProc{$svcPID} = int($1);
		}
		elsif ( $line =~ /Processes in Current Activity Manager State:/ )	{
			$iPhase = 0;
			$bDebugging = 0;
			plog ("Found start sign");		
		}
	}
	elsif ($iPhase == 0)
	{		
		if ($nPid==0 && $line =~ /\*APP\* UID (\d+) ProcessRecord{\S+\s(\d+):(\S+)\/(\d+)/ )
		{
			plog ("\n\t* process=$3\tUID=$1\tpid=$2\t/whatis?=$4");
			$nPid=int($2);
			
			push @aProc, $3;
			push @aPID, int($2);
			
			#$hProc{$nPid} = $3;
			
								
			#$maxLengProc = ($maxLengProc < length($3) ? length($3) : $maxLengProc);
		}

		elsif ($nPid>0 && $line =~ /\s+lastActivityTime=(\S+) lruWeight=(\S+) (.*)/ )
		{
			plog ("\t\t lastActivityTime=$1 lruWeight=$2 / $3");		
			push @aLru, $2;
			
			$hLru{$nPid} = $2;
			$hLastAct{$nPid} = $1;
		}
		
	#	elsif ($nPid==1 && $line =~ /\s+oom: max=(\d+) hidden=(\d+) curRaw=(\d+) setRaw=(\d+) cur=(\d+) set=(\d+)/ )
		elsif ($nPid>0 && $line =~ /\s+oom: (.+)$/ )
		{
			plog ("\t\t oom=$1");
			push @aStrOom, $1 ;
			
			
			# int($1) if ( $1 =~ /cur=(\d+)/ );			
			$hCurAdj{$nPid} = int($1) if ( $1 =~ /cur=(\d+)/ );
			plog ("\t\t CurAdj=$hCurAdj{$nPid}");
			$nPid=0;
		}
		# for GB
		elsif ( $line =~ /Running processes \(most recent first\):/ )	{
			plog ("\n ** now we meet the stack list. we gathered $#aPID pids. **");
			$bIsICS = 0;
			$iPhase++;
		}
		# for ICS
		elsif ( $line =~ /Process LRU list \(sorted by oom_adj\):/ )	{
			plog ("\n ** now we meet the stack list.  we gathered $#aPID pids. **");
			$bIsICS = 1;
			$iPhase++;
		}
	}
	
#
#	NOW match with stack list!!
#
	elsif ($iPhase == 1)
	{
		if (( $line =~ /(\S{4}) #\s*(\d+): adj=(\S{3,5})\s*\/\S \S+ (\d+):(\S+)\/(\d+) (\S+)/ && !$bIsICS) || 
			($line =~ /(\S{4}) #\s*(\d+): adj=(\S{3,5})\s*\/\S+\s+trm=\s*\d (\d+):(\S+)\/(\d+) (\S+)/ && $bIsICS))
		{
			plog (" lru list! - $1 $2 $3 $4 $5 $6 $7");
			my $pid = int($4);
			$cntPERS++ if ( $1 eq "PERS" );
			if (!$bIsICS)
			{
				if ( $2 == $cntStack ) {$cntStack++;}
				else { print "\nSomething wrong!\n"; last; }	
			}
			else { $cntStack++; }
			push @aOrder, ($pid);
			$hAdjType{$pid} = $7;
			SumAdjType ($7);	
			$hProc{$pid} = $5;	
			$hUid{$pid} = $6;
			$hAdj{$pid} = $3;
			
			$maxLengProc = ($maxLengProc < length($5) ? length($5) : $maxLengProc);
			$maxLengAdjType = ($maxLengAdjType < length($7) ? length($7) : $maxLengAdjType);			
			
				
		}
		elsif ( $line =~ /PID mappings:/ ) 
		{
			$iPhase++;
			plog ("\n ** now we meet the PID mappings! **");
		}
		
	}
	
#
#	Grep PSSs
#	
	elsif ($iPhase == 2)
	{
		if ($nPid == 0 && $line =~ /\*\* MEMINFO in pid (\d+) \[(\S+)\] \*\*/ )
		{
			plog ("\t\t - met pid info for $1");
			$countPhase2++;
			$nPid=$1;
		}
		elsif ( $nPid > 0 && $bIsICS ==0 && $line =~ /\s+\(Pss\):\s+\S+\s+\S+\s+\S+\s+\S+\s+(\S+)/ )
		{
			$hPss{$nPid} = int($1);
			$TotalPssSum+=int($1);
			$nPid=0;
		}
		elsif ( $nPid > 0 && $bIsICS ==1 && $line =~ /\s+TOTAL\s+(\S+)/ )
		{
			plog ("\t\t\t and also found pss $1");
			$hPss{$nPid} = int($1);
			$TotalPssSum+=int($1);
			$nPid=0;
		}
	}
}
=cut
for ( my $idx = 0 ; $idx <= $#aLru ; $idx++ )
{
	plog ("$idx\t".$aLru[$idx]."\t".$aProc[$idx]."\t".$aPID[$idx]);
}
=cut

# reorder the list.
my @reOrder;
my $i = @aOrder;
foreach (0..$i)
{	
	my $pid=-1;
	my $index = 0;
	my $adj=100;
	my $j=0;
	
	foreach ( @aOrder ) 
	{		
		#print $hCurAdj{$_}." ";
		if (!(defined $hCurAdj{$_}))
		{
			$pid = $aOrder[$j];
			$adj = $hCurAdj{$pid};			
			$index = $j;
			last;
		}
		elsif (defined $hCurAdj{$_})		
		{
			if ($adj > $hCurAdj{$_} )
			{
				$pid = $aOrder[$j];
				$adj = $hCurAdj{$pid};			
				$index = $j;
				#print "($pid/$adj/$index) ";
			}
		}
		#$adj = 100 if (!looks_like_number($adj));
		$j++;
	}	
	#print " - $pid, $index \n";
	push @reOrder, $pid if ($pid>0);
	#$aOrder[$index] = 0;	#or 
	splice @aOrder,$index,1;
}

#=cut
my $iOrder=1;
$maxLengProc = 50;

print "\n no  pid "; print " Process"; print " " foreach(6..$maxLengProc-1);
print "Adjust type"; print " " foreach(11..$maxLengAdjType); print " cur  Pss    Lru   adj   last CPU time\n";
print " -- ----- "; print "-" foreach(0..$maxLengProc-1);print " ";
print "-" foreach(0..$maxLengAdjType); print " --- ---- -------- ----- ------------\n";
	
while ( my $pid = shift @reOrder )
{			
	my $strProc = defined $hProc{$pid} ? $hProc{$pid} : "";
	$strProc = ( length($strProc) > $maxLengProc ) ? substr ($strProc, 0, $maxLengProc-3)."..": $strProc;
	
	printf (" %2d %5d %s",$iOrder++,$pid, $strProc);
	print " " foreach(length($strProc)..$maxLengProc);
	#printf (" %5d %s",$hUid{$pid},$hAdjType{$pid});
	print ("$hAdjType{$pid}");
	print " " foreach(length($hAdjType{$pid})..$maxLengAdjType);	
	defined($hCurAdj{$pid}) ? printf " %2d",$hCurAdj{$pid}: print "  -";
	defined($hPss{$pid}) ? printf " %5d",$hPss{$pid}: print "     -";
	defined($hLru{$pid}) ? printf " %8d",$hLru{$pid}: print "     -   ";	
	defined($hAdj{$pid}) ? printf " %s",$hAdj{$pid}: print "     -";
	print " " foreach(length($hAdj{$pid})..6);	
	defined($hLastAct{$pid}) ? printf "%s",$hLastAct{$pid}: print "   -";
	my $nblank = defined($hLastAct{$pid})?( 15 - length($hLastAct{$pid}) ): 11 ;	
	print " " foreach(0..$nblank);
	defined($hSvcProc{$pid}) ? printf "%s",$hProc{$hSvcProc{$pid}}: print "   -";
	print "\n";
}

print "\n ".($#aProc+1)." processes found in dumpsys / $cntStack processes found in Stack. ( $cntPERS persistent processes )\n\n";

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


# summary for adj.
my $PssSumBak=0;
my $CntBak = 0;
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
	if ( $adj =~ /bak/)
	{
		$PssSumBak += $PssSum;
		$CntBak += $SumAdj{$adj};
	}
	else 
	{	print " $adj\t: $PssSum kB ($SumAdj{$adj})\n"; }
}
print " bak\t: $PssSumBak kB ($CntBak)\n";
print "\n";

=cut
# summary for adj. type
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
=cut

printf " total Pss = %.2f MB (%d kB)   !! please mind, this pss`s are collected from 'dumpsys' which is smaller than from 'procrank'.\n", ($TotalPssSum/1024), $TotalPssSum;
#=cut
	
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

