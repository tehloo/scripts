mkdir %1_dump\
adb shell getprop > %1_dump\TargetInfo.txt
echo " "; echo " - Adj+MinFree"
adb shell cat /sys/module/lowmemorykiller/parameters/adj >> %1_dump\TargetInfo.txt
adb shell cat /sys/module/lowmemorykiller/parameters/minfree >> %1_dump\TargetInfo.txt

adb shell cat /proc/meminfo > %1_dump\meminfo.txt
adb shell cat /proc/vmallocinfo > %1_dump\vmallocinfo.txt

adb shell procrank > %1_dump\procrank.txt
adb shell dumpsys > %1_dump\dumpsys.txt
adb shell dmesg > %1_dump\dmesg.txt
adb logcat -v time > %1_dump\logcat.txt
