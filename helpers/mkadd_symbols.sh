#!/bin/ksh

SYMBOLS=$1;
OFFSET=$2;
if [ -z "${OFFSET}" ]; then OFFSET=0; fi

if [ ! -f "${SYMBOLS}" ]; then exit; fi

awk '$1==".text"&&$NF~/\.o$/{print "add-symbol-file",$NF,$2}' "${SYMBOLS}" \
| while read INSTR OBJ ADDR; do
    ADDR=`echo print\(hex\(${OFFSET} + ${ADDR}\)\) | python3 -`
    OBJ=`echo ${OBJ} | sed -e 's/\.\.\/\.//'`
    echo ${INSTR} ${OBJ} ${ADDR}
done \
| sed -e 's/^/            "/' -e 's/$/",/'