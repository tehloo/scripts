#!/usr/bin/perl -w

# getBroadcast.pl
#
# released on 2014.03.19
#


use strict;
use warnings;
use POSIX 'isatty';
use Cwd 'abs_path';

use Time::Piece;




# CONTANTS...........................................................
#my $startIntent = "android.intent.action.USER_BACKGROUND";
my $startIntent = "android.intent.action.USER_STARTED";
#my $startIntent = "lge.settings.QMODE_ON_PLEASE";
#my $startIntent = "android.media.AUDIO_BECOMING_NOISY";
#my $endIntent = "android.intent.action.USER_SWITCHED";
#my $endIntent = "android.intent.action.USER_STOPPED";
my $endIntent = "android.intent.action.BOOT_COMPLETED";
#my $endIntent = "android.media.AUDIO_BECOMING_NOISY";
#my $endIntent = "lge.settings.QMODE_CHANGED";

my $showNotExist = 0;
my $showReceivers = 1;
my $showLogtime = 1;

my @intentToIgnore = (
		"android.intent.action.BATTERY_CHANGED",
		"android.intent.action.TIME_TICK",
		"lge.android.intent.action.CKERROR",
		"com.lge.android.intent.action.BATTERYEX"		
	);

my $intentToFindReceivers = "android.intent.action.BOOT_COMPLETED";
#my $intentToFindReceivers = "android.media.AUDIO_BECOMING_NOISY";
#my $intentToFindReceivers = "lge.settings.QMODE_ON";

# hashes and arrays for parsing......................................
my @broadcastList = ();		# get UID as array list.
my %broadcastHash = ();		# hash for (UID, href for intent records)
my %prevBroadcastHash; 		# copy a hash

my @receiverList = ();		# array for (UID, href for receiver records);
my @arrayStartedApp = ();

# variables for parsing..............................................
#my $count = 0;
my $maxLenIntent = 0;
my $bStarted = 0;

my ($dtStart, $dtEnd);
my ($timeStart, $timeEnd);

my $startNFinish = "";


# regular expressions
my $REGEX_TAG_ACTIVITY_MANAGER = qr/\d+-\d+ (\S+)\s+\d+\s+\d+\s\S\sActivityManager:(.*)$/;
my $REGEX_TAG_BROADCAST_QUEUE = qr/\d+-\d+ (\S+)\s+\d+\s+\d+\s\S\sBroadcastQueue:(.*)$/;

my $REGEX_DELIVERY_START =  qr/Processing (\S+) broadcast \[(\S+)\] BroadcastRecord\{(\S+) \S+ (\S+)\}/;

my $REGEX_ORDERED_DELIVERY_FINISH = qr/Finished with ordered broadcast BroadcastRecord\{(\S+) \S+ (\S+)\}/;
my $REGEX_PARALLEL_DELIVERY_FINISH = qr/Done with parallel broadcast \S+ BroadcastRecord\{(\S+) \S+ (\S+)\}/;

my $REGEX_DELIVERING_TO_RECEIVER_LIST = qr/Delivering to BroadcastFilter\{\S+ u\S+ (ReceiverList\{\S+ \S+ \S+ \S+\})\} \(\S+\): BroadcastRecord\{(\S+) u\S+ (\S+)\}/;
# 	01-06 20:00:27.933  1148  2014 V BroadcastQueue: Process cur broadcast BroadcastRecord{16f467f3 u0 android.intent.action.BOOT_COMPLETED} for app ProcessRecord{172541ac 2025:com.android.phone/1001}
my $REGEX_DELIVERING_TO_APP = qr/Process cur broadcast BroadcastRecord\{(\S+) u\S+ (\S+)\} DELIVERED for app (.*)$/;
#	01-06 20:00:27.933  1148  2014 V BroadcastQueue: Delivering to component ComponentInfo{com.android.phone/com.android.phone.OtaStartupReceiver}: BroadcastRecord{16f467f3 u0 android.intent.action.BOOT_COMPLETED}
my $REGEX_DELIVERING_TO_APP_COMPONENT = qr/Delivering to component ComponentInfo\{(\S+)\}: BroadcastRecord\{(\S+) u\S+ (\S+)\}$/;

my $REGEX_NEED_APP_START = qr/Need to start app \S+ (\S+) for broadcast BroadcastRecord\{(\S+) u\S+ (\S+)\}/;
my $REGEX_ENQUEUE_BR = qr/Enqueueing (\S+) broadcast BroadcastRecord\{(\S+) \S+ (\S+)\}/;



# get filename or STDIN via pipe.
if ( ! @ARGV && isatty(*STDIN) ) {
    die "usage: getBroadcast.pl <FILE_PATH_logger> <INTENT_NAME>";
}

# open file as dir or single file.
my $HF;
my @gFileList = ();
my $gHash_fileIndexComplete = 0;

if (@ARGV) {
	if ( -d $ARGV[0] ) {		
		getFilename($ARGV[0], \@gFileList);
		die "\nfile not found...\n" if scalar @gFileList == 0;
		
	} elsif ( -f $ARGV[0] ) {
		push @gFileList, $ARGV[0];
	}
}
else {
#	$HF = \*STDIN;
	die "usage: ...";
}

subScanFileToParse();

sub subScanFileToParse 
{
	my $filecount = scalar @gFileList;
	my @arrayIndex = ();

	while ($filecount) {
		$filecount--;
		my $filename = $gFileList[$filecount];
		
		open ($HF, $filename);
		
		# read line by line
		print " READ $filename...\n";
		
		my $lineCount = 0;
		
		while ( my $line = <$HF> )
		{
		#	parseInline($line);
			$lineCount++;
			if ( $line =~ /$REGEX_TAG_BROADCAST_QUEUE/ ) {		
				my $time = $1;

				if ( $2 =~ /$REGEX_ORDERED_DELIVERY_FINISH/ || $2 =~ /$REGEX_PARALLEL_DELIVERY_FINISH/) {
					my $uid = $1;
					my $intent = $2;
					if ($2 eq $endIntent) {
						my $index = scalar @arrayIndex;
						print $line;
						
						while ($index) {
							$index--;
							my $href = $arrayIndex[$index];
							if (exists $href->{'enqueEndIntentUid'}) {
								if ($href->{'enqueEndIntentUid'} eq $uid) {
									$href->{'endFile'} = $filename;
									$href->{'endLine'} = $lineCount;
									last;
								}
							}						
						}
					}
				}

			} elsif ( $line =~ /$REGEX_TAG_ACTIVITY_MANAGER/ ) {
				my $time = $1;

				if ($2 =~ /$REGEX_ENQUEUE_BR/) {
				
					my $intent = $3;
					
					if ($intent eq $startIntent) {
					print $line;
						my %hash_fileIndex = ();
						$hash_fileIndex{'startFile'} = $filename;
						$hash_fileIndex{'startLine'} = $lineCount;
						push @arrayIndex, \%hash_fileIndex;

					} elsif ($intent eq $endIntent) {
					print $line;
						my $href = $arrayIndex[-1];
						$href->{'enqueEndIntentUid'} = $2;
					}
				}
			}
		}
	}
	
	my $cycleCount = 0;
	# pick last cycle to parse.
	while (my $href = pop @arrayIndex) {
		if (exists $href->{'endFile'}) {
			# only last cycle choose!
			# $gHash_fileIndexComplete = $href if ($gHash_fileIndexComplete == 0);

			# first cycle choose!!
			$gHash_fileIndexComplete = $href;

			$cycleCount++;
		}
	}

	print "\n Scan completed... " ;
	print "$cycleCount times cycles in log...\n";
	if ($cycleCount > 0) {
		print "\t from ".$gHash_fileIndexComplete->{'startFile'}." line #".$gHash_fileIndexComplete->{'startLine'};
		print "\n\t to ".$gHash_fileIndexComplete->{'endFile'}." line #".$gHash_fileIndexComplete->{'endLine'}."\n";
	} else {
		die "\n unable to get any information from this log file.\n";		
	}
	#printHash (\%hash_fileIndexComplete, "\n");
	print "\n";
}




my $filecount = scalar @gFileList;

while ($filecount) {
	$filecount--;
	my $filename = $gFileList[$filecount];
	
	next if ($gHash_fileIndexComplete->{'startFile'} ne $filename);
	print " parsing $filename...\n";
	
	my $lineCount = 0;
	open ($HF, $filename);
	
	while ( my $line = <$HF> )
	{
		$lineCount++;
		next if ($gHash_fileIndexComplete->{'startFile'} eq $filename
					&& $gHash_fileIndexComplete->{'startLine'} > $lineCount);
		last if parseInline($line, $lineCount) == -1;
		last if ($gHash_fileIndexComplete->{'endFile'} eq $filename
					&& $gHash_fileIndexComplete->{'endLine'} < $lineCount);
	}
}



sub getFilename 
{
	my $path = shift;
	my $fileList = shift;

	opendir(dirHandle, $path) || die "Failed to open. check the path : \\$path";
	my @files = readdir( dirHandle );	# get every files from dirHandle.
	closedir dirHandle;
	
#	$path = $path."/" if ($path =~ /.*\//)
	
	foreach (@files) {
		push @$fileList, ($path."/$_") if ($_ =~ /system\.log.*/);
	}
}


sub parseInline {
	my $line = shift;
	my $count = shift;
	
	if ($bStarted == 2) {
		%prevBroadcastHash = %broadcastHash;	# copy all~
		return -1;
	}
	
	if ( $line =~ /$REGEX_TAG_BROADCAST_QUEUE/ ) {
	
		my $time = $1;
		my $proc = "";
		my $pid = "";
		my $task = "";
		my $etc = "";
		
#		print $line;
#		print $1." / ".$2."\n";

		if ( $2 =~ /$REGEX_DELIVERY_START/) {
			updateIntent($count, $3, $time, 'deliveryStart', $1, $4, $2);
			
		} elsif ( $2 =~ /$REGEX_ORDERED_DELIVERY_FINISH/) {
			updateIntent($count, $1, $time, 'deliveryFinish', 'ordered', $2);
			pushReceiver($1, "finfinfin", $time, $2);

		} elsif ($2 =~ /$REGEX_PARALLEL_DELIVERY_FINISH/) {
			updateIntent($count, $1, $time, 'deliveryFinish', 'parallel', $2);

		} elsif ( $2 =~ /$REGEX_DELIVERING_TO_RECEIVER_LIST/) {
			addReceiverCount($2);
			pushReceiver($2, $1, $time, $3);
=cut
#my $REGEX_DELIVERING_TO_APP = qr/Process cur broadcast BroadcastRecord\{(\S+) u\S+ (\S+)\} DELIVERED for app (.*)$/;
		} elsif ( $2 =~ /$REGEX_DELIVERING_TO_APP/) {
			addReceiverCount($1);
			pushReceiver($1, $3, $time, $2);
=cut
#my $REGEX_DELIVERING_TO_APP_COMPONENT = qr/Delivering to component ComponentInfo\{(\S+)\}: BroadcastRecord\{(\S+) u\S+ (\S+)\}$/;
		} elsif ( $2 =~ /$REGEX_DELIVERING_TO_APP_COMPONENT/) {
			my $intent = $3;
			my $uid = $2;
			my $receiver = $1;
			addReceiverCount($1);
			pushReceiver($uid, $receiver, $time, $intent);

		} elsif ( $2 =~ /$REGEX_NEED_APP_START/) {
			my $appName = $1;
			my $intentUid = $2;
			my $intent = $3;

			appStartedForReceiver($appName, $intentUid, $intent);		
			
		}

	} elsif ( $line =~ /$REGEX_TAG_ACTIVITY_MANAGER/ ) {
		my $time = $1;

		if ($2 =~ /$REGEX_ENQUEUE_BR/) {
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
	return 0;
}


sub updateIntent {
			my $count = $_[0];
			my $uid = $_[1];
			my $time = $_[2];
			my $field = $_[3];
			my $type = $_[4];
			my $intent = $_[5];
			my $priority = $_[6] if defined($_[5]);
			
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

my $uidToFindReceivers;

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
			
			$uidToFindReceivers = $uid if !($uidToFindReceivers);
			if ($uid eq $uidToFindReceivers) {
			
				my %pReceiver = (
						uid => $uid,
						receiver => $receiver,
						time => $time,
						appStart => $appName
						);

				push @receiverList, \%pReceiver;		
			}
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
my $gap = $maxLenIntent-22;
print " " while ($gap-- > 0);
print " receivers\ten.Q  ~~  Delivery  ~~  Finish\t en.Q~finish\t start~Fin.\n\n";

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
		
		if (($deliveryStart ne 0 && $deliveryFinish ne 0 )|| $ignoreNotDelivered == 0) {
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
			print "\n ".$#receiverList." Receivers for $intentToFindReceivers \n";
			

			my $prevTime = 0;
			my $countStartedApp = 0;
			my $sumDuration = 0;
			my $prevHref = 0;
			my $countReceiver = scalar @receiverList;
			
			while ( $countReceiver-- ) {
			
				my $href = shift (@receiverList);
			
				if ($prevHref ne 0) {
					my $receiver = $prevHref->{'receiver'};
					my $time = $prevHref->{'time'};
					my $nextTime = $href->{'time'};
					my $durationTime = getDt($nextTime) - getDt($time);
					my $appStarted = $prevHref->{'appStart'};
					$prevTime = getDt($time);
					
					my $delimeter = "-";
					if (length($appStarted) > 0) {
						$delimeter = "+" ;
						$countStartedApp++;
					}
					
					if ($showReceivers > 0) {					
						print " $delimeter";
						my $strDuration = subCommifyInt($durationTime);
						my $space = 8 - length($strDuration);
						print " " while ($space--);
						print " $strDuration ms / $receiver\n";
					}
					$sumDuration += $durationTime;

				}
				$prevHref = $href;
			}

			printf "\n ".subCommifyInt($sumDuration)." ms takes and";
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
	
	print "$enqueueTime" if $showLogtime;
	if ($deliveryStart ne 0)
	{printf " %7d ms ",(getDt($deliveryStart) - getDt($enqueueTime))}
	else
		{print "\t\t\t";	}
	print "$deliveryStart" if $showLogtime;;
	
	if ($deliveryStart ne 0)
		{printf " %7d ms ",(getDt($deliveryFinish) - getDt($deliveryStart))}
	else
		{print "\t\t\t";}
	print "$deliveryFinish" if $showLogtime;;
	
	printf "\t %7d ms ", getDt($deliveryFinish) - getDt($enqueueTime) if ($deliveryStart ne 0);
	printf "\t %7d ms ", getDt($deliveryFinish) - getDt($timeStart) if ($deliveryStart ne 0);
	print "\n";
	
#	print "\n" if ($endIntent eq $intent) 
}

# insert commas for big number
sub subCommify {
    my $text = reverse $_[0];
    $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
    return scalar reverse $text
}

sub subCommifyInt {
	use integer;
	
    my $num = $_[0];
	my $return = "";
	
	while ($num > 0) {
		my $right = $num % 1000;
		my $left = $num / 1000;

		$return = ",".$return if (length($return) > 0);
		if ($left > 0 && $right < 10) { $return = "00".$right.$return; }
		elsif ($left > 0 && $right < 100) { $return = "0".$right.$return; }
		else {$return = $right.$return; }
		
		last if ($left == 0);
		$num = $left;
	}

	return $return;
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



