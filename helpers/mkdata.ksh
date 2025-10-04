#!/bin/ksh

DATA=$1
shift
if [ -z "${DATA}" ]; then
	echo "Usage: $0 filename" >&2
	exit 1
fi

HEXSTR="0 1 2 3 4 5 6 7 8 9 A B C D E F"

for A in $HEXSTR; do
	for B in $HEXSTR; do
		for C in $HEXSTR; do
			for D in 0 4 8 C; do
				echo -e $A$B$C$D\\c;
			done;
		done;
	done;
done > "${DATA}"
