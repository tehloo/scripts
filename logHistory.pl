#!/usr/bin/perl -w

use strict;
use warnings;
use POSIX 'isatty';
#use Win32::Console::ANSI;



if ( ! @ARGV && isatty(*STDIN) ) {
    die "usage: ...";
}

my $HF;

if (@ARGV)
{
	open ($HF, $ARGV[0]) if ( -f $ARGV[0]  );
}
else {$HF = \*STDIN;}

my $count = 0;
my $maxProcLeng = 50;
my $maxTaskLeng = 18;


my %hAct = ();
my %hAdd = ();
my %hBrd = ();
my %hCnt = ();
my %hSvc = ();
my %hEtc = ();

my %hTrace = ();



while ( my $line = <$HF> )
{
	$count++;
	if ( $line =~ /\d+-\d+ (\S+) \S\/ActivityManager\(\s*\d+\):/ )
	{
		my $time = $1;
		my $proc = "";
		my $pid = "";
		my $task = "";
		my $etc = "";
		
		if ( $line =~ /Start proc (.*)$/ )
		{
			#print " !! $1\n";
			$line = $1;
			if ( $line =~ /(\S+) for (\S+) (\S+): pid=(\d+)/ )
			{
				$proc = $1; $pid = $4; $task = "start_$2";				
				if ( $2 eq "activity" ) 	{$hAct{$pid} = $time;}
				elsif ( $2 eq "broadcast" ) {$hBrd{$pid} = $time; $etc=$3;}
				elsif ( $2 eq "service" ) 	{$hSvc{$pid} = $time;}
			}
			elsif ( $line =~ /(\S+) for added application (\S+): pid=(\d+)/ )
			{
				#print $count." $1($3) start_added_app $time\n";
				$proc = $1; $pid = $3; 
				$task = "start_added_app";
				$hAdd{$pid} = $time;
			}
#01-18 10:01:39.799 I/ActivityManager(  209): Start proc android.process.media for content provider com.android.providers.media/.MediaProvider: pid=2392 uid=10024 gids={1015, 2001, 3003, 4002}			
			elsif ( $line =~ /(\S+) for content provider (\S+): pid=(\d+)/ )
			{
				#print $count." $1($3) start_content_prov. $time\n";
				$proc = $1; $pid = $3; 
				$task = "start_content_prov.";
				$hCnt{$pid} = $time;
				$etc = $2;
			}				
		}

		elsif ( $line =~ /No longer want (\S+) \(pid (\d+)\): hidden #(\d+)/ )
		{
			#print $count." $1($2) no_longer $time hidden#$3\n";
			$proc = $1;
			$pid = $2;
			$task = "no_longer_need";
#			$etc = popPid($pid, $time);
		}
		elsif ( $line =~ /Scheduling restart of crashed service (\S+) in (\d+)/ )
		{
			#print $count." $1 rescheduling $time $2ms\n";
			$proc = "$1";
			$task = "rescheduling";
			$etc = "$2ms";
		}
		elsif ( $line =~ /Process (\S+) \(pid (\d+)\) has died./ )
		{
			#print $count." $1($2) died $time\n";
			$proc = $1;
			$pid = $2;
			$task = "died";
#			$etc = popPid($pid, $time);			
		}
		#invoke INTENT on GB
#                         Starting: Intent { act=android.intent.action.MAIN cat=[android.intent.category.LAUNCHER] flg=0x10200000 cmp=com.google.android.gm/.ConversationListActivityGmail bnds=[123,542][237,686] } from pid 512
		elsif ( $line =~ /Starting: Intent { act=android.intent.action.MAIN cat=\[android.intent.category.LAUNCHER\] flg=\S+ cmp=(\S+)/ )
		{
			#print $count."    <<<-$1->>> INVOKED $time\n";
			$proc = "->>>$1";
			$task = "INVOKED";
			$etc = "";
		}
		#invoke INTENT on ICS
		elsif ( $line =~ /START {act=android.intent.action.MAIN cat=\[android.intent.category.LAUNCHER\] flg=\S+ cmp=(\S+)}/ )
		{
			#print $count."    <<<-$1->>> INVOKED $time\n";
			$proc = "->>>$1";
			$task = "INVOKED";
			$etc = "";
		}
		
		# go home on GB
		elsif ( $line =~ /Starting: Intent { act=android.intent.action.MAIN cat=\[android.intent.category.HOME/ )
		{
			#print $count."    <<<-$1->>> INVOKED $time\n";
			$proc = "<<<-HOME";
			$task = "GO_HOME";
			$etc = "";
		}
		# go home on ICS
		elsif ( $line =~ /START {act=android.intent.action.MAIN cat=\[android.intent.category.HOME/ )
		{
			#print $count."    <<<-$1->>> INVOKED $time\n";
			$proc = "<<<-HOME";
			$task = "GO_HOME";
			$etc = "";
		}
		
		# trace force to -14
		elsif ( $line =~ /Set app (\S+) oom adj to (\S+)/ )
		{
			my $adj = int($2);
			if ( $adj == -14 && !(defined $hTrace{$1})) 
			{				
				$proc = "$1";
				$task = "* force to -14 *";
				$etc = "";			
				$hTrace{$proc} = -14;
			}
			elsif ( defined $hTrace{$1} ) 
			{
				$proc = "$1";
				$task = "* loose to $adj *";
				$etc = "";
				delete $hTrace{$proc};
			}
		}
		
		
		#now show the result.
		if ( $proc ne "" )
		{
			print "$count\t";
			$proc = substr($proc,0,$maxProcLeng-9).".." if (length($proc) > ($maxProcLeng-9));			
			$proc.="($pid) " if ($pid ne "");
			print $proc;
			print " " foreach(length($proc)..$maxProcLeng);	
			printf "%s ",$task;
			print " " foreach(length($task)..$maxTaskLeng);	
			printf "%s ",$time;
				
			# etc
			printf " %s",$etc;
			
			print "\n";
		}
	}
}


#use DateTime::Format::Strptime qw();

sub popPid 
{
#	my $p = DateTime::Format::Strptime->new(pattern => '%T', on_error => 'croak',);
	
	my $pid = $_[0];
	my $sign = "none";
#	my $timeFormat = "hh:mm:ss.mmm";
	
#	my $now = $p->parse_datetime($_[1]);
	my $time;
	
	$sign = "remove_activity" 	if $time=delete $hAct{$pid};
	$sign = "remove_added_app" 	if $time=delete $hAdd{$pid};
	$sign = "remove_broad_cst" 	if $time=delete $hBrd{$pid};
	$sign = "remove_cnt_prov." 	if $time=delete $hCnt{$pid};	
	$sign = "remove_service" 	if $time=delete $hSvc{$pid};
	$sign = "remove_etc" 		if $time=delete $hEtc{$pid};
	
	$sign .= "($pid)";
	
	return $sign;
}