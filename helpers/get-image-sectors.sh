BYTES=`stat -c %s ./shadow-os.img`
SECTORS=`expr $BYTES / 512`
expr 1 + $SECTORS
