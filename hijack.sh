#!/temp/bin/sh

# add /temp/bin to path
PATH="/temp/bin:$PATH"

###
#
# PART OF HIJACK RAMDISK
#
###
# 
# Copyright (c) 2016 Izumi Inami (droidfivex)
# 
# Permission is hereby granted, free of charge, to any person obtaining a 
# copy of this software and associated documentation files (the 
# "Software"), to deal in the Software without restriction, including 
# without limitation the rights to use, copy, modify, merge, publish, 
# distribute, sublicense, and/or sell copies of the Software, and to 
# permit persons to whom the Software is furnished to do so, subject to 
# the following conditions:
#
# The above copyright notice and this permission notice shall be 
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, 
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF 
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND 
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE 
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION 
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION 
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
###
#
# collect informations.
# unmount testing.
# hijack recovery.
#

# [ VOL + ]: hijack recovery
#
# put this file to /system/hijack/hijack.sh
#
###

# put on the led lights
LED () {
	local red="/sys/class/leds/lm3533-red/brightness" 
	local green="/sys/class/leds/lm3533-green/brightness"
	local blue="/sys/class/leds/lm3533-blue/brightness" 
	if [ "$1" = "" ]; then
		echo 0 > $red
		echo 0 > $green
		echo 0 > $blue
	else
		echo $1 > $red
		echo $2 > $green
		echo $3 > $blue
	fi
}

# prepare, remount / and create folders
PREPARE () {
	mount -o remount,rw rootfs /
	cd /
	mkdir -p /temp/event/
}

# send message
KMSG () {
	echo $1 > /dev/kmsg
}

# unmount
UNMOUNT () {
	# partitions list from every rc files,
	# fstab.qcom and result of mount command
	umount -l /acct
	umount -l /cache
	umount -l /data
	umount -l /dev/cpuctl
	umount -l /dev/pts
	umount -l /dev
	umount -l /dtvtmp/dtv
	umount -l /lta-label
	umount -l /mnt/asec
	umount -l /mnt/idd
	umount -l /mnt/obb
	umount -l /mnt/qcks
	umount -l /mnt/secure
	umount -l /mnt/shell/emulated
	umount -l /proc
	umount -l /storage/emulated/legacy
	umount -l /storage/removable/sdcard1
	umount -l /sys/kernel/debug
	umount -l /sys
	umount -l /system

	# write changes
	sync
}

# remove 
REMOVE () {
	rm -rf /init* /ueventd* /etc /d /ext_card /sdcard /sdcard1 /tmp /usbdisk /vendor
}

# process killer
KILLER () {
	local runningsvc
	local runningsvcname
	local runningprc
	local lockingpid
	local binary

	# kill services
	for runningsvc in $(getprop | grep -E '^\[init\.svc\..*\]: \[running\]' | grep -v ueventd)
	do
		runningsvcname=$(expr ${runningsvc} : '\[init\.svc\.\(.*\)\]:.*')
		stop $runningsvcname
		if [ -f "/system/bin/${runningsvcname}" ]; then
			pkill -f /system/bin/${runningsvcname}
		fi
	done

	# kill processes
	for runningprc in $(ps | grep /system/bin | grep -v grep | grep -v chargemon | awk '{print $1}' ) 
	do
		kill -9 $runningprc
	done
	for runningprc in $(ps | grep /sbin | grep -v grep | awk '{print $1}' )
	do
		kill -9 $runningprc
	done

	# kill locking pidfile
	for lockingpid in `lsof | awk '{print $1" "$2}' | grep "/bin\|/system\|/data\|/cache" | awk '{print $1}'`
	do
		binary=$(cat /proc/${lockingpid}/status | grep -i "name" | awk -F':\t' '{print $2}')
		if [ "$binary" != "" ]; then
			killall $binary
		fi
	done

	sync
}

# VIBRAT
VIBRAT () {
	local viberator="/sys/class/timed_output/vibrator/enable"
	if [ "$1" = "" ]; then
		echo 150 > $viberator
	else
		echo $1 > $viberator
	fi
}

# unset
UNSET () {
	unset LED
	unset PREPARE
	unset KMSG
	unset MAIN
	unset UNMOUNT
	unset SWITCH
	unset VIBRAT
	unset HIJACK
	unset KILLER
}

# hijack
HIJACK () {
	if [ "$1" = "" ]; then
		exit 1
	fi

	# AQUAMARINE
	LED 127 255 212

	# prepare hijack
	KILLER
	sleep 1
	UNMOUNT
	REMOVE
	sleep 1

	# unpack ramdisk image
	cd /
	if [ -f /temp/ramdisk/ramdisk-$1.img ]; then
		gzip -dc /temp/ramdisk/ramdisk-$1.img | cpio -i
	elif [ -f /temp/ramdisk/ramdisk-$1.cpio ]; then
		cpio -idu < /temp/ramdisk/ramdisk-$1.cpio
	fi

	# write changes
	sync

	# power off LED...
	LED

	# hijack!
	chroot / /init
}

# get switch
SWITCH () {
	# declaration
	local eventdev
	local suffix
	local catproc

	# vibration / light PURPLE
	LED 150 50 255
	VIBRAT

	# get event
	for eventdev in $(ls /dev/input/event*)
	do
		suffix="$(expr ${eventdev} : '/dev/input/event\(.*\)')"
		cat ${eventdev} > /temp/event/key${suffix} &
	done
	sleep 2

	# kill cat (4 rows up)
	for catproc in $(ps | grep " cat" | grep -v grep | awk '{print $1;}')
	do
		kill -9 ${catproc}
	done
	sleep 1

	# tell end of cat events to users / off led
	LED

	# check keys event
	hexdump /temp/event/key* | grep -e '^.* 0001 0073 .... ....$' > /temp/event/keycheck_up
	hexdump /temp/event/key* | grep -e '^.* 0001 0072 .... ....$' > /temp/event/keycheck_down

	# VOL +
	if [ -s /temp/event/keycheck_up ]; then
		KMSG "[hijack] hijack to recovery..."
		HIJACK recovery
	elif [ -s /temp/event/keycheck_down ]; then
		KMSG "[hijack] hijack to system..."
		HIJACK system
	fi
}

# main
MAIN () {
	KMSG "[hijack] prepareing..."
	PREPARE

	KMSG "[hijack] collect informations..."
	CHECKENV

	# switch
	SWITCH

	# clean-up
	UNSET
}

MAIN
