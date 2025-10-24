#!/bin/ksh

if [ ! -z "${GDB}" ]; then
	GDBOPTS="-s -S"
else
	GDBOPTS=""
fi

if [ -z "${IMAGE}" ]; then
	MF=`dirname $0`/Makefile
	IMAGE=`awk '$1=="IMAGE"{print $NF}' "${MF}"`
fi

/usr/bin/qemu-system-i386 ${GDBOPTS} -cpu 486 -drive file="${IMAGE}",format=raw -m 1 -serial stdio
