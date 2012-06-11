mkdir %1_getLogger\
adb pull /data/anr %1_getLogger/anr
adb pull /data/dontpanic %1_getLogger/dontpanic
adb pull /data/logger %1_getLogger/logger
adb pull /data/tombstones %1_getLogger/tombstones