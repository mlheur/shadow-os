#!/bin/ksh

HEXSTR="0 1 2 3 4 5 6 7 8 9 A B C D E F"

for A in $HEXSTR; do
	for B in $HEXSTR; do
		for C in $HEXSTR; do
			for D in 0 4 8 C; do
				echo -e $A$B$C$D\\c;
			done;
		done;
	done;
done > ./data
