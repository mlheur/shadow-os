#!/bin/ksh

if [ -z "${MODULE}" ]; then
    if [ -z "${1}" ]; then MODULE=mbr
    else; MODULE=$1; shift 1; fi
fi

make clean || exit
make || exit

HELPERS=`dirname $0`/helpers

## Update the project.seer project file with new symbol locations.
test -f project.seer.orig || cp project.seer project.seer.orig
# Get the first part of the file, up until add-s
awk '{
    print
    if($0~/pregdbcommands/){exit}
}' project.seer.orig > project.seer
# insert symbols.  ToDo: find a way to add the offset by reference instead of hard-coding it here.
case "${MODULE}" in
    "mbr")
        "${HELPERS}/mkadd_symbols.sh" ./dumps/${MODULE}.symbols 0x7a00 | grep _start >> project.seer
        "${HELPERS}/mkadd_symbols.sh" ./dumps/${MODULE}.symbols 0x7c00               >> project.seer
        ;;
    *)
        "${HELPERS}/mkadd_symbols.sh" ./dumps/${MODULE}.symbols 0x7c00               >> project.seer
esac
# Finish the file from 'set arch i8086' onward
awk 'BEGIN{FLAG=0}{
    if($0~/set arch i8086/){FLAG=1}
    if(FLAG){print}
}' project.seer.orig >> project.seer

# Start the debugging session in a subshell
{
    seergdb --project project.seer &\
    GDB=1 ./qemu.sh;
}

