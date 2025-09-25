#!/bin/ksh

if [ ! -z "${GDB}" ]; then
	GDBOPTS="-s -S"
else
	GDBOPTS=""
fi

/usr/bin/qemu-system-i386 ${GDBOPTS} -cpu 486 -drive file=`cat .image`,format=raw -m 1 -serial stdio
