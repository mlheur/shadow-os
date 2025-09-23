#!/bin/ksh
while [ -z "${PTS}" ]; do 
	PTS=`ls -l /dev/pts | awk '$3=="qemu"{print "/dev/pts/"$NF}'`
	if [ ! -z "${PTS}" ]; then break; fi
	sleep 0.1
done
sudo cat ${PTS}
