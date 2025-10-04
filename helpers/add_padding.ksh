#!/bin/ksh

IMAGE=$1;

if [ ! -f "${IMAGE}" ]; then exit; fi

BYTES=`stat -c %s "${IMAGE}"`
SECTORS=`expr "${BYTES}" / 512`
SECTORS=`expr 1 + "${SECTORS}"`
PADS=`expr 128 - "${SECTORS}"`

`dirname $0`/mkdata.ksh ./data || exit 1
dd if=./data of=${IMAGE} bs=512 seek=${SECTORS} skip=${SECTORS} count=${PADS} || exit 2
rm ./data || exit 3