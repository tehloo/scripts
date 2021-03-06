#!/usr/bin/perl -w

use strict;
use warnings;
use Cwd 'abs_path';
use Time::Piece;

###########################
# OPTIONS. you can give whatever you want.
#
	my $factorStart = 2;		# under 3, 3~4, 4~5....
	my $factorCount = 5;		# how many columns...
#	my $ignoreCount = 0;		# ignore process data which has counted as given.
	my $dpTimeToFile = 1;		# option : saving text file for Displayed time.
	my $assumeResumeTimeAs = 100;		#
	my $opGetAssumedResult = 1;		# 
	my $opIgnoreProcName = "com.nhn.android.search";

	
###########################
# variables.
#
	my @logfiles = ();			# list for MainLog files
	my $path = "logger";		# path to find MainLog files.
	my $error = 0;				# it will count errors from parsing phase.
	my $warning = 0;			# it will count warning from parsing and count for summary.
	my $lenLongestProc = 0;		# find longest process name for summary output format.

	# variables for Loading time by main log
	my %hashProc = ();			# key = proc / data = array index.
	my @results = ();			# 2d array. 1st = count / 2nd = sum of duration / 3rd and further = count for each factors.
	my $totalCount = 0;			# it will count logs for "Displayed time"
	my $countAgain = 0;			# it will count every loading time counts to be compared with $totalCount.
	my $startTime = 0;
	my $endTime = 0;
	
	my $startTime2 = 0;
	my $endTime2 = 0;
	
	
	# variables for Resume rate by system log
	my $launchedCount = 0;
	my $restartedCount = 0;
	my %hashLaunch = (); 		# key = proc / data = launch count.
	my %hashStart = ();			# key = proc / data = start count.

	# variables for Resume rate by event log
	my $launchedCountEvent = 0;
	my $restartedCountEvent = 0;
	my %hashRestart = (); 	# key = proc / data = restart count.
	my %hashResume = ();	# key = proc / data = resume count.
	
	# filename for output
	my $outDisplayList = "displayed.txt";
	if ($dpTimeToFile > 0)
	{		
		open my $output_fh, ">", $outDisplayList or die "ERROR! when open output file\n $!\n";
		print $output_fh "log_time process.activity displayed_time";
		close $output_fh;	
	}
	
	# as reference, Assumed Proc/Act name which is not matched exactly.
	my %assumedProcAct = ();
	my $assumedProcActMaxLen = 0;
	
	# if a argument has given, it will be the path of log files.
	$path = $ARGV[0] if ($#ARGV == 0);

###########################
# now we go.
#
	print "\n\n";
	getFilename();							# get file list for MainLog from 'logger' dir.
	getLines($_) foreach (@logfiles);		# read log lines from file array and parse each lines.
	resultLoadingTime();					# make summary from gathered datas.

#	resultResumeBySystem();
#	resultResumeByEvent();
#
# job completed.
###########################


###########################
# sub functions.
#

sub setStartEndTime
{
	my $timeStr = $1 if ( $_[0] =~/(\d+-\d+\s\d+:\d+:\d+)\./); 
#	print ("$timeStr / ");
	my $timestamp = Time::Piece->strptime( $timeStr, "%m-%d %H:%M:%S");
#	print ("$timestamp | ");
	$startTime = $timestamp	if ($startTime eq "" || $startTime > $timestamp);
	$endTime = $timestamp if ($startTime eq "" || $endTime < $timestamp);
}

sub getAppropriateName
{
	my $aFrom = $_[0];
	my $proc = $_[1];
	my $bGetHistory = $_[2];
	
	if (!defined($$aFrom{$proc}))
	{
#		print "\n *** find $proc .. ";
		foreach my $procHash (keys %$aFrom)
		{
			my @split = split(/\//, $proc);
			if ( $procHash =~ /$split[0]/ )
			{
#				print "  --> seems like $procHash \n";
				if ( $bGetHistory == 1 && !defined($assumedProcAct{$proc})) {
					$assumedProcAct{$procHash} = $proc;
					$assumedProcActMaxLen = $assumedProcActMaxLen < length($proc) ? length($proc) : $assumedProcActMaxLen;
				}
				$proc = $procHash;
				last;
			}
		}
#		print "\n";		
	}
	
	return $proc;	 
}


sub getLaunchCnt
{
	my $procAct = $_[0];
	my $return = 0;
		
	$procAct = getAppropriateName(\%hashLaunch, $procAct,0);	
	if (defined($hashLaunch{$procAct}))
	{
		#	유사한 Process에 값이 적용될 수 있으니, 한번 return된건 해시 키를 삭제한다.
		$return = delete $hashLaunch{$procAct};		
	}
	return $return;
}

sub remainedLC 
{
	return if (0 == keys %hashProc );
	print "\n - remained(not presented) loaded process info (from main log)\n";
	foreach (sort keys %hashProc )
	{
		print " $_($hashProc{$_})\n";
	}
}

sub putOneRecord
{
	my $proc = $_[0];
	my $tLaunchCnt = $_[1];
	my $aSummary = $_[2];
	my $aAsSum = $_[3];
	
	# get index 
	my $procIdx = delete $hashProc{$proc};
		

	my $checksum = 0;
	my $idx = 2;
	print " $proc ";
	print " " foreach (length($proc)..$lenLongestProc);		


	my $tCount = 0;
	my $tSum = 0;
	my $tAvg = 0;
	my $aRef = 0;
			
	if (defined($procIdx))
	{
		$tCount = shift @{$results[ $procIdx ]};
		$tSum = shift @{$results[ $procIdx ]};
		$tAvg = $tSum/$tCount;
		$aRef = $results[ $procIdx ];
	}				
	
	# start to write real data.
	printf ("%3d  %3d",$tCount, $tLaunchCnt);	
		
	print " " if ($tAvg < 1000);
	print " " if ($tAvg < 10000);
	printf (" %5.1f  ", $tAvg);	
	@$aSummary[0]+=$tCount;				# count.
	@$aSummary[1]+=$tSum;				# average.
	
	@$aAsSum[0]+=$tLaunchCnt;			# count. 	(but useless)
#	@$aAsSum[1]+=$tSum;					# average.	(but useless)

	foreach (1..$factorCount)
	{
		my $iVal = shift @{$aRef} if $aRef > 0;
		my $index = $_;
		if (defined($iVal)) {
			printf(" %3d  ", $iVal );
			$checksum+=$iVal;
			@$aAsSum[$idx] += $iVal if ($tLaunchCnt > 0);
			@$aSummary[$idx]+=$iVal; 
		}
		else {
			print  "  -   ";
		}
		
		#			if ($index == 1 )	# TODO: SHOULD BE FIXED LATER.
		my $addAssume = 0;
		$addAssume++ if ($index == 1 && $assumeResumeTimeAs <= $factorStart * 1000);
		$addAssume++ if ($index > 1 && 
							$assumeResumeTimeAs > ($factorStart+$index-2) * 1000 &&
							$assumeResumeTimeAs <= ($factorStart+$index-1) * 1000);
		$addAssume++ if ($index == $factorCount && 
							$assumeResumeTimeAs >= ($factorStart+$index-1) * 1000);
		if ($addAssume > 0 && $assumeResumeTimeAs > 0) {
			@$aAsSum[$idx] += ($tLaunchCnt-$tCount ) if ($tLaunchCnt>$tCount);
#			print "(+@$aAsSum[$idx]) ";
		}
		
		$idx++ if (defined($iVal));
	}
	
	# add assumed resume time, if $assumeResumeTimeAs if over then 0
	if ($assumeResumeTimeAs > 0)
	{
		my $assumedCnt = ($tCount > $tLaunchCnt)? $tCount : $tLaunchCnt;
		my $resumedCnt = ($tCount > $tLaunchCnt)? 0 : $tLaunchCnt-$tCount;
		my $assumedAvg = ($tSum + $resumedCnt*$assumeResumeTimeAs)/$assumedCnt;
		print " " if $assumedAvg < 1000;			
		printf "%5.1f",$assumedAvg ;
		@$aAsSum[1]+=($assumedAvg*$assumedCnt);
		
#		printf( " %d %d(%d)", $tSum, @$aAsSum[1],$resumedCnt);
	}
#	printf( " (%3d) ", $tLaunchCnt-$tCount);

	#check count and sum
	print " NOK!" if ( $checksum != $tCount );
	$countAgain+=$checksum;

	print "\n";
}


# make summary from gathered datas.
sub resultLoadingTime
{
	my @aSummary = ();
	my @aNoUserLaunched = ();
	my $LaunchSum = 0;
	my @aAsSum = ();
	
	# write titles.
	print "\n\n\n +++ RESULT for Loading time +++ ( start factor : $factorStart / factor count : $factorCount )\n";
	print "     Resume time has assumed as $assumeResumeTimeAs, and it will be involved into Average Loading time\n" if ($assumeResumeTimeAs>0);  
	print "\n Process"; print " " foreach(8..$lenLongestProc);
	print " Load Launch Avg.  ";
	print " 0~$factorStart   ";
	printf (" %d~%d  ",($_-1),$_) foreach ($factorStart+1..$factorStart+$factorCount-2);
	print " over".($factorStart+$factorCount-1)."\n\n";
	
	# write results for each processes.
#	foreach my $proc ( sort keys %hashProc) 
	foreach my $proc ( sort keys %hashLaunch)
	{
		my $tLaunchCnt = getLaunchCnt($proc);
		if ($tLaunchCnt == 0) {										# skip process which is not launched by user.
			push @aNoUserLaunched, $proc;
			$totalCount -= $results[ $hashProc{$proc} ][0];			# result[procName][0] has Display Count for procName. 
			next;
		}

		# get appropriate proc name;
		if (!defined($hashProc{$proc}))	{
#			print "\n   - $proc is ";
			$proc = getAppropriateName(\%hashProc, $proc, 1 );
#			print "$proc\n";
		}	

		putOneRecord($proc, $tLaunchCnt, \@aSummary, \@aAsSum);
		$LaunchSum += $tLaunchCnt;		
	}	
	putSummary(\@aSummary, $LaunchSum, "summary for above");
	putSummary(\@aAsSum, $LaunchSum, "assumed summary for above") if ($assumeResumeTimeAs> 0);
			
	print "\n - Processes which is NOT launched by user\n";		
	foreach my $proc ( sort keys %hashProc) {
		my $tLaunchCnt = getLaunchCnt($proc);
		putOneRecord($proc, $tLaunchCnt, \@aSummary, \@aAsSum);
		$LaunchSum += $tLaunchCnt;
	}
	putSummary(\@aSummary, $LaunchSum, "summary for all");
#	putSummary(\@aAsSum, $LaunchSum, "assumed summary for all") if ($assumeResumeTimeAs> 0);
	remainedLC();
		
	# put assumed processes
	print "\n\n - Assumed processes (Launch A, but Displayed as B)\n";
	foreach my $assumedProc ( sort keys %assumedProcAct )
	{		
		print " $assumedProcAct{$assumedProc}";
		print " " foreach (length($assumedProcAct{$assumedProc})..$assumedProcActMaxLen);		
		print " -> $assumedProc\n";
	}
		
	# check result data.
	print "\n";
	if ($countAgain == $totalCount)
	{	print " + $totalCount logs parsed and it all looks good!\n";	}
	else
	{	print " + Something's wrong!!! total parsed $totalCount. but result has $countAgain.\n";}
	print " + $warning warnings. you'd better to check log above.\n" if ($warning > 0); 
	print " + $error ERRORS! Something is wrong from PARSING phase.\n" if ($error > 0);	
	
	# print time
	print "\n + log time \n";
	my $strformat = "%m-%d %H:%M:%S";	
	# Put log time. for system log
	print "   * As system log, ";
	print $startTime->strftime($strformat); print " ~ "; print $endTime->strftime($strformat); 
	$startTime = $endTime -$startTime;
	printf " ( %d days, %d hours, %d minutes and %d seconds )\n",(gmtime $startTime->seconds)[7,2,1,0];
	# Put log time. for event log	
	print "   * As event log,  ";
	print $startTime2->strftime($strformat); print " ~ "; print $endTime2->strftime($strformat); 
	$startTime2 = $endTime2 -$startTime2;
	printf " ( %d days, %d hours, %d minutes and %d seconds )\n",(gmtime $startTime2->seconds)[7,2,1,0];
	
	print "\n";
}

sub putSummary
{
	my $aSummary = $_[0];
	my $LaunchSum = $_[1];
	my $nameSummary = $_[2];
	
	# show summary / SUM of count	
	print "\n $nameSummary";
	print " " foreach (length($nameSummary)..$lenLongestProc);	
	print "@$aSummary[0]/$LaunchSum ";
	printf (" %.1f  ",@$aSummary[1]/@$aSummary[0]);
	printf ("%3d   ", @$aSummary[$_]) foreach (2..$#$aSummary);
	
	# show summary / AVG of displayed time.
	print "\n";
	print " " foreach (0..$lenLongestProc+17);
	printf (" %.1f%% ",@$aSummary[$_]*100/@$aSummary[0]) foreach (2..$#$aSummary);
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
	my $job = 0;		# 0 : getLoadingTime / 1 : getResumeRate / 2: getResumeRate by event
	$job = 1 if ($_ =~ /system\.log.*/);
	$job = 2 if ($_ =~ /events\.log.*/);
	
	# for ResumeRate
	my $justLaunched = "";
	
	open my $fh, "<", $_ or die "Cannot open file - $_";
	my $count =0;
	print " - Parsing $_ ...";
	
	# open output file if needed
	open my $output_fh, ">>", $outDisplayList or die "ERROR! when open output file\n $!\n" if ($dpTimeToFile > 0 && $job == 2);

	while (my $line = <$fh> )
	{
		if ($job == 2)	# parsing event log
		{
			if ($line =~ /^(\d+-\d+\s\d+:\d+:\d+)\.\d+.*\sI\sam_activity_launch_time:\s\[\d+,\d+,(\S+),(\S+),(\S+)\]/ )
			{
				#print " $1 - ";
				
				my $timestamp = Time::Piece->strptime( $1, "%m-%d %H:%M:%S");
				next if ( $timestamp <= ($startTime) || $timestamp >= ($endTime+10) );
				
				$startTime2 = $timestamp if ($startTime2 > $timestamp || $startTime2 == 0);
				$endTime2 = $timestamp if ($endTime2 < $timestamp);
				
				print "launch_time - $2, $3 and $4\n" if ($3 > $4);
				my $proc = $2;
				my $durSec = $3;
				pushToHashDisplay ($proc, $durSec);
				
#				print "FOUND! - $timestamp $proc $durSec\n" if ($proc =~/facebook/);				
				print $output_fh "\n$timestamp $proc $durSec";
				
				$count++;
			}		
=cut		
			if ($line =~ /^(\d+-\d+\s\d+:\d+:\d+\.\d+)\sI\/am_restart_activity.*:\s\[\d+,\d+,(\S+)\]/ )
			{
				#print "Restart - $2\n";
				pushToHashEvent( $2, 0);
				$justLaunched = $1 if ( $2 =~ /(\S+)\/\S+/);	# get process name without activity name.
				$count++;
			}
			elsif ($line =~ /^(\d+-\d+\s\d+:\d+:\d+\.\d+)\sI\/am_resume_activity.*:\s\[\d+,\d+,(\S+)\]/ )
			{
				#print "Resume - $2\n";
				pushToHashEvent( $2, 1);
				$justLaunched = $1 if ( $2 =~ /(\S+)\/\S+/);	# get process name without activity name.
				$count++;
			}			
			elsif ($line =~ /^(\d+-\d+\s\d+:\d+:\d+\.\d+)\sI\/am_on_resume_called.*:\s(\S+)/ )
			{
				#print "on Resume Called- $2\n";
				if ( $2 =~ /$justLaunched/ )
				{
				
				}
				else
				{	
					#print " something wrong - $2's resume called instead $justLaunched\n";	
				}
			}	
=cut			
		}
		elsif ( $job == 1) # parsing system log
		{
			if ( $line =~ /^(\d+-\d+\s\d+:\d+:\d+)\.\d+.*I\sActivity.*:\sSTART\su0\s{act=android.intent.action.MAIN cat=\[android.intent.category.LAUNCHER\]\s\S+\scmp=(\S+)}\s/ )
			{	# Launched.
				my $timestamp = Time::Piece->strptime( $1, "%m-%d %H:%M:%S");
				$startTime = $timestamp if ($startTime > $timestamp || $startTime == 0);
				$endTime = $timestamp if ($endTime < $timestamp);
				
				#print ("\n + $1 - LAUNCHED...$2..");
				next if ($line =~ /$opIgnoreProcName/);
				pushToHashResume( $2, 0);
				#print "000 - $1, $2\n";
				$justLaunched = $1 if ( $2 =~ /(\S+)\/\S+/);	# get process name without activity name.			
				#print "001 - $justLaunched\n";
				$count++;
			}
			elsif ( $line =~ /^(\d+-\d+\s\d+:\d+:\d+\.\d+).*I\sActivity.*:\sStart proc\s(\S+)\sfor\sactivity\s(\S+):/ )
			{	# it is "Start process" as it means. it is not Activity Resume.
				#print "111 - $1, $2 - $line\n";
				if ( $2 eq $justLaunched )
				{
					pushToHashResume( $3, 1);
					#print "112 - $2 + $3\n";
				}
			}
		}
=cut		
		# or count for Displayed time.
		elsif ( $line =~ /^(\d+-\d+\s\d+:\d+:\d+\.\d+)\sI\/Activity.*:\sDisplayed\s(\S+):\s(\+\S+ms)/ )
		{
#			print $1." - ".$2." > ".$3."\n";
			next if ($line =~ /$opIgnoreProcName/);
			
			my $logTime = $1;
			my $proc = $2;
			my $durSec = 0;
			setStartEndTime($logTime);
			
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
			
			pushToHashDisplay ($proc, $durSec);
			print $output_fh "\n$logTime $proc $durSec" if (defined($output_fh));
#			print "$logTime $proc $durSec\n" if (defined($output_fh));
		}
=cut		
	}
	print "\tFound $count ";
	print "\"START...\"" if ($job==1);
	print "\"Displayed...\"" if ($job==0);	
	print " in lines.\n";
	close $fh;
	#$totalCount += $count if ($job==0);
	$totalCount += $count if ($job==2);
	$launchedCount += $count if ($job==1);
	
	if (defined($output_fh))
	{
#		print "\n displayed processes list is saved in ".$output_fh."\n";
		close $output_fh;
	}
}

# receive process name and flag (0=Restart/1=Resume)
sub pushToHashEvent 
{
	my $proc = $_[0];
	my $flag = $_[1];	
	
	if ( $flag == 0 )
	{
		$hashRestart{$proc} 	= 0 if (!defined($hashRestart{$proc}));
		$hashRestart{$proc}++;
#		print "0 $proc - $hashLaunch{$proc}\n";
	}
	if ( $flag == 1 )
	{	
		$hashResume{$proc} 	= 0 if (!defined($hashResume{$proc}));
		$hashResume{$proc}++;
#		print "1 $proc - $hashStart{$proc}\n";
	}
}



# receive process name and flag (0=Launch/1=Start)
sub pushToHashResume 
{
	my $proc = $_[0];
	my $flag = $_[1];	
	
	if ( $flag == 0 )
	{
		$hashLaunch{$proc} 	= 0 if (!defined($hashLaunch{$proc}));
		$hashLaunch{$proc}++ 	;
#		print "0 $proc - $hashLaunch{$proc}\n";
	}
	if ( $flag == 1 )
	{
		$hashStart{$proc} 	= 0 if (!defined($hashStart{$proc}));
		$hashStart{$proc}++;
#		print "1 $proc - $hashStart{$proc}\n";
	}
}

# receive process name and displayed time
# initialize and build hash for proc name and array for data.
sub pushToHashDisplay
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
	opendir(dirHandle, $path) || die "Failed to open. check the path : \\$path";
	my @files = readdir( dirHandle );	# get every files from dirHandle.
	closedir dirHandle;  # 꼭 닫읍...
=cut
	# get MainLog files and push to logfiles array.
	foreach (@files) {
		push @logfiles,abs_path($path."\\".$_) if ($_ =~ /main\.log.*/);
	}
=cut	
	foreach (@files) {
		push @logfiles,abs_path($path."\\".$_) if ($_ =~ /system\.log.*/);
	}
	
	foreach (@files) {
		push @logfiles,abs_path($path."\\".$_) if ($_ =~ /events\.log.*/);
	}
}




#########################################################################
### sub routines below would be used for test.
#########################################################################

sub resultResumeByEvent
{
	# write titles.
	print "\n\n +++ RESULT for Resume rate by Event log +++ \n\n";
	print " Process"; print " " foreach(8..$lenLongestProc); print " Launched  Restarted  Resumed\n";	
	foreach my $proc ( sort keys %hashRestart)
	{
		my $launchCount = $hashRestart{$proc};
		my $resumeCount = defined($hashResume{$proc}) ? $hashResume{$proc} : 0;
		delete $hashResume{$proc} if ($resumeCount > 0);
		
		print "\n $proc";
		print " " foreach ( length($proc)..$lenLongestProc );
		printf (" %6d",$resumeCount+$launchCount);
		printf (" %8d",$launchCount);
		printf (" %8d",$resumeCount);
		
	}
	print "\n\n";
	print " Remained Process"; print " " foreach(18..$lenLongestProc); print " Resumed\n";
	foreach my $proc ( sort keys %hashResume)
	{
		my $launchCount = $hashResume{$proc};
		print "\n $proc";
		print " " foreach ( length($proc)..$lenLongestProc );
		printf (" %6d",$launchCount);
	}
	print "\n\n";
}

sub resultResumeBySystem
{
	# write titles.
	print "\n\n +++ RESULT for Resume rate by System log +++ \n\n";
	print " Process"; print " " foreach(8..$lenLongestProc);
	print " Launched  Started  Resumed   R.rate\n";
	
	foreach my $proc ( sort keys %hashLaunch)
	{
		my $launchCount = $hashLaunch{$proc};
		my $startCount = defined( $hashStart{$proc} )? $hashStart{$proc}: 0;
		print "\n $proc";
		print " " foreach ( length($proc)..$lenLongestProc );
		printf (" %6d",$launchCount);
		printf (" %8d",$startCount);
		printf (" %7d",$launchCount - $startCount);
		printf (" %9.2f%%",($launchCount - $startCount)*100/$launchCount) if ($launchCount >0);
	}
	print "\n\n";
	
	foreach my $proc ( sort keys %hashStart)
	{
		my $launchCount = defined( $hashLaunch{$proc} )? $hashLaunch{$proc} : 0;
		my $startCount = defined( $hashStart{$proc} )? $hashStart{$proc}: 0;
		print "\n $proc";
		print " " foreach ( length($proc)..$lenLongestProc );
		print "\t $launchCount";
		print "\t $startCount";
		printf ("\t %d",$launchCount - $startCount);
		printf ("\t %f",($launchCount - $startCount)*100/$launchCount) if ($launchCount >0);
	}

}
