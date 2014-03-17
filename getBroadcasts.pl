#!/usr/bin/perl -w

use strict;
use warnings;
use POSIX 'isatty';

use Time::Piece;


# get filename or STDIN via pipe.
if ( ! @ARGV && isatty(*STDIN) ) {
    die "usage: ...";
}

# open file 
my $HF;
if (@ARGV) {
	open ($HF, $ARGV[0]) if ( -f $ARGV[0]  );
}
else {
	$HF = \*STDIN;
}

# CONTANTS...........................................................
#my $startIntent = "android.intent.action.USER_BACKGROUND";
my $startIntent = "android.intent.action.USER_STARTED";
#my $endIntent = "android.intent.action.USER_SWITCHED";
#my $endIntent = "android.intent.action.USER_STOPPED";
my $endIntent = "android.intent.action.BOOT_COMPLETED";

my $showNotExist = 0;
my $showReceivers = 1;

my @intentToIgnore = (
		"android.intent.action.BATTERY_CHANGED",
		"android.intent.action.TIME_TICK",
		"lge.android.intent.action.CKERROR"		
	);

my $intentToFindReceivers = "android.intent.action.SCREEN_OFF";

# hashes and arrays for parsing......................................
my @broadcastList = ();		# get UID as array list.
my %broadcastHash = ();		# hash for (UID, href for intent records)
my %prevBroadcastHash; 		# copy a hash

my @receiverList = ();		# array for (UID, href for receiver records);

# variables for parsing..............................................
my $count = 0;
my $maxLenIntent = 0;
my $bStarted = 0;

my ($dtStart, $dtEnd);
my ($timeStart, $timeEnd);

my $startNFinish = "";






# read line by line
while ( my $line = <$HF> )
{
	$count++;
	
	if ($bStarted == 2) {
		%prevBroadcastHash = %broadcastHash;	# copy all~
		last;
	}
	
	if ( $line =~ /\d+-\d+ (\S+)\s+\d+\s+\d+\s\S\sBroadcastQueue:(.*)$/ ) {
	
		my $time = $1;
		my $proc = "";
		my $pid = "";
		my $task = "";
		my $etc = "";
		
#		print $line;
#		print $1." / ".$2."\n";

		if ( $2 =~ /Processing (\S+) broadcast \[(\S+)\] BroadcastRecord\{(\S+) \S+ (\S+)\}/) {
			updateIntent($3, $time, 'deliveryStart', $1, $4, $2);
			
		} elsif ( $2 =~ /Finished with ordered broadcast BroadcastRecord\{(\S+) \S+ (\S+)\}/) {
			updateIntent($1, $time, 'deliveryFinish', 'ordered', $2);

		} elsif ($2 =~ /Done with parallel broadcast \S+ BroadcastRecord\{(\S+) \S+ (\S+)\}/) {
			updateIntent($1, $time, 'deliveryFinish', 'parallel', $2);

		} elsif ( $2 =~ /Delivering to BroadcastFilter\{\S+ u\S+ (ReceiverList\{\S+ \S+ \S+ \S+\})\} \(\S+\): BroadcastRecord\{(\S+) u\S+ (\S+)\}/) {
			addReceiverCount($2);
			pushReceiver($2, $1, $time, $3);

		} elsif ( $2 =~ /Process cur broadcast BroadcastRecord\{(\S+) u\S+ (\S+)\} DELIVERED for app (.*)$/) {
#			print $line;
			addReceiverCount($1);
			pushReceiver($1, $3, $time, $2);
			#			Need to start app [background] com.google.android.gm for broadcast BroadcastRecord{42d0d800 u10 android.intent.action.BOOT_COMPLETED}
		} elsif ( $2 =~ /Need to start app \S+ (\S+) for broadcast BroadcastRecord\{(\S+) u\S+ (\S+)\}/) {
			my $appName = $1;
			my $intentUid = $2;
			my $intent = $3;

			appStartedForReceiver($appName, $intentUid, $intent);		
			
		}

	} elsif ( $line =~ /\d+-\d+ (\S+)\s+\d+\s+\d+\s\S\sActivityManager:(.*)$/ ) {
		my $time = $1;

#		print $1." / ".$2."\n";
#				   Enqueueing parallel broadcast BroadcastRecord
#			      /Enqueueing ordered broadcast BroadcastRecord{43048978 u-1 android.intent.action.USER_STARTING}: prev had 0
		if ($2 =~ /Enqueueing (\S+) broadcast BroadcastRecord\{(\S+) \S+ (\S+)\}/) {
#			print " * enqueue ... ".$line;
			my $type = $1;
			my $uid = $2;
			my $intent = $3;
			
			if ($bStarted == 0 && $intent eq $startIntent) {
				$bStarted = 1;
				$timeStart = $time;
				$startNFinish = " START - $startIntent at line#$count ($time)";
			}
			
			if ($bStarted == 1) {
#				print $line;
				makeIntent($type, $uid, $intent, $time);			
				$maxLenIntent = length($intent) if ($maxLenIntent < length($intent));
			}
		}
	}
}

sub updateIntent {
			my $uid = $_[0];
			my $time = $_[1];
			my $field = $_[2];
			my $type = $_[3];
			my $intent = $_[4];
			my $priority = $_[5] if defined($_[5]);
			
			if (exists $broadcastHash{$uid}) {
#				print "EXIST! ";
				my $href = $broadcastHash{$uid};
				if ($href->{'type'} eq $type) {
					$href->{$field} = $time;
					$href->{'priority'} = $priority if defined($priority);
					
					#finish. if needed.
					if ($field eq "deliveryFinish" && $intent eq $endIntent && $bStarted == 1) {
						$bStarted = 2;
						$timeEnd = $time;
						$startNFinish = $startNFinish."\n FINISH - $endIntent at line#$count ($time)\n";
					}
					
				} elsif ($showNotExist) {
					print "NOT EXIST!!!! intent $uid/ $field for $intent ($count)\n";
				}
				
#			print " $field = $href / $uid / $time/ $href->{'deliveryFinish'}/ $href->{'priority'}\n";
			} elsif ($showNotExist) {
				print "NOT EXIST! intent $uid/ $field for $intent ($count)\n";
			}
}

sub addReceiverCount {
			my $uid = $_[0];
			
			if (exists $broadcastHash{$uid}) {
#				print "EXIST!\n";
				my $href = $broadcastHash{$uid};
				my $addVal = $href->{'receiverCount'};
				$href->{'receiverCount'} = $addVal + 1;
				
#				print " receiverCount= $href->{'receiverCount'}\n";
			} elsif ($showNotExist) {
				print "NOT EXIST! receiver $uid\n";
			}
}

sub makeIntent {
#			print $1." / ".$2."\n";
			my $type = $_[0];
			my $uid = $_[1];
			my $intent = $_[2];
			my $time = $_[3];
			
			foreach my $ignore ( @intentToIgnore ) {
				return if ($ignore eq $intent);
			}
			
			my $broadcastHref;			
			my %pBroadcast = (
					uid => $uid,
					intent => $intent,
					type => $type,
					enqueueTime => $time,
					deliveryStart => "0",
					deliveryFinish => "0",
					receiverCount => 0,
					priority => "0"
					);
			$broadcastHref = \%pBroadcast;
			$broadcastHash{$uid} = $broadcastHref;
			push @broadcastList, $uid;			
			
#			print "enqueue as %pBroadcast\n";
}

my @arrayStartedApp = ();

sub pushReceiver {
			my $uid = $_[0];
			my $receiver = $_[1];
			my $time = $_[2];
			my $intent = $_[3];
			
			return if ($intent ne $intentToFindReceivers);
			my $appName ="";
			
			if (scalar @arrayStartedApp > 0) {
				$appName = pop @arrayStartedApp ;
				if ($appName ne getAppName($receiver)) {
					push @arrayStartedApp, $appName;
					$appName = "";				
				}
			}
			
			
			my %pReceiver = (
#					uid => $uid,
					receiver => $receiver,
					time => $time,
					appStart => $appName
					);

			push @receiverList, \%pReceiver;		
}

sub getAppName {
	my $Receiver = shift;
	my $appName = "";
	
	if ($Receiver =~ /ProcessRecord\{\S+ \d+:(\S+)\/u\S+\}/) {
		$appName = $1;		
	}
	return $appName;
}



sub appStartedForReceiver {
			my $appName = $_[0];
			my $uid = $_[1];
			my $intent = $_[2];
			
			return if ($intent ne $intentToFindReceivers);
			
			push @arrayStartedApp, $appName;
}

######################################
####  scan and list up!
######################################
my %hash_IntentType = ();

print "\n\n  ==== show all Intents ====\n\n";
my $ignoreNotDelivered = 1;
my $countNotDelivered = 0;

print " uid\t    type \t Broadcast Intent ";
my $gap = $maxLenIntent-20;
print " " while ($gap--);
print " receivers\t enqueue time\t\t delivery start\t\t delivery finish\n\n";

foreach my $uid ( @broadcastList ) {
	if (exists $broadcastHash{$uid}) {
		my $href = $broadcastHash{$uid};
		my $intent = $href->{'intent'};
		my $deliveryStart = $href->{'deliveryStart'};
		my $type = $href->{'type'};
		my $enqueueTime = $href->{'enqueueTime'};
		my $deliveryFinish = $href->{'deliveryFinish'};
		my $receiverCount = $href->{'receiverCount'};
		
		if (exists $hash_IntentType{$intent}) {
			$hash_IntentType{$intent} = $hash_IntentType{$intent} + 1;
		} else {
			$hash_IntentType{$intent} = 1;
		}
		
		if ($deliveryStart ne 0 || $ignoreNotDelivered == 0) {
			print " $uid "; 
			printIntent($href, "\t");
		} else {
			$countNotDelivered++;
		}
		
#print "$intent\n";
	} else {
		print "!!!NOT EXIST! $uid\n";
	}
}


######################################
####  get summary!!
######################################
print "\n\n";
print "$startNFinish\n";
print " DURATION = ".getSecond(getDt($timeEnd) - getDt($timeStart))." sec.\n\n";
print " ";
print scalar @broadcastList. " broadcasts";
print " ($countNotDelivered broadcasts has delivered after $endIntent and not counted)\n";



=cut
print "\n\n  ==== count all Intents ====\n\n";
printHash(\%hash_IntentType, "\n");
=cut



summaryReceivers();

######################################
####  get receivers
######################################
sub summaryReceivers {
			print "\n ". scalar @receiverList." Receivers for $intentToFindReceivers \n";

			my $prevTime = 0;
			my $countStartedApp = 0;
			my $sumDuration = 0;

			foreach my $href ( @receiverList ) {
				my $receiver = $href->{'receiver'};
				my $time = $href->{'time'};
				my $durationTime = $prevTime > 0 ? getDt($time) - $prevTime : 0;
				my $appStarted = $href->{'appStart'};
				$prevTime = getDt($time);
				
				my $delimeter = "-";
				if (length($appStarted) > 0) {
					$delimeter = "+" ;
					$countStartedApp++;
				}
				
				printf " %s %6d ms / %s\n", $delimeter, $durationTime, $receiver if $showReceivers > 0;
				$sumDuration += $durationTime;
			}

			printf "\n %d ms takes and", $sumDuration;
			print " $countStartedApp app started for $intentToFindReceivers.\n";
			print "\n\n";

			print @arrayStartedApp;
}



######################################
####  sub modules now on.
######################################

sub printIntent {
	my $href = $_[0];	
	my $intent = $href->{'intent'};
	my $deliveryStart = $href->{'deliveryStart'};
	my $type = $href->{'type'};
	my $enqueueTime = $href->{'enqueueTime'};
	my $deliveryFinish = $href->{'deliveryFinish'};
	my $receiverCount = $href->{'receiverCount'};
	my $priority = $href->{'priority'};
=cut	
	my $dt_queue = Time::Piece->strptime($enqueueTime, "%H:%M:%S.A%3N");
	my $dt_start = Time::Piece->strptime($deliveryStart, "%H:%M:%S.A%3N");
	my $dt_fin = Time::Piece->strptime($deliveryFinish, "%H:%M:%S.A%3N");
=cut	
	
	print "[F]" if ($priority eq "foreground");
	print "[B]" if ($priority eq "background");
	print "$type ";
	
	print "\t$intent";
	my $gap = $maxLenIntent - length($intent);
	print " " while ($gap--);
	print " $receiverCount\t";
	
	print "$enqueueTime";
	if ($deliveryStart ne 0)
	{printf " ~(%4d ms)~  ",(getDt($deliveryStart) - getDt($enqueueTime))}
	else
		{print "\t\t\t";	}
	print "$deliveryStart";
	
	if ($deliveryStart ne 0)
		{printf " ~(%4d ms)~  ",(getDt($deliveryFinish) - getDt($deliveryStart))}
	else
		{print "\t\t\t";}
	print "$deliveryFinish";
	
	print " [".getSecond(getDt($deliveryFinish) - getDt($deliveryStart))."s/" if ($deliveryStart ne 0);
	print getSecond(getDt($deliveryFinish) - getDt($timeStart))."s]" if ($deliveryStart ne 0);
	print "\n";
	
#	print "\n" if ($endIntent eq $intent) 
}

sub printHash {
	my $hash_ref = $_[0];
	my $delimeter = $_[1];
	my $sumValue = 0;
#	print "%".$hash_ref."\n";
	while ( my ($key, $value) = each %$hash_ref) {
		print " $key=$value$delimeter";
		$sumValue += $value;
	}
	
	print "\n sum = $sumValue\n\n";	
}

sub getDt {
	my $time = $_[0];
	my $millis = 0;

	if ( $time =~ /(\d{2}):(\d{2}):(\d{2})\.(\d{3})/) {
		my $h = $1;
		my $m = $2;
		my $s = $3;
		my $ms = $4;
		
		$millis = ((($h * 60) + $m) * 60 + $s) * 1000 + $ms;
		return $millis;
	}
	return 0;
}

sub getSecond {
	my $sec = $_[0] / 1000;
	return $sec;
}



