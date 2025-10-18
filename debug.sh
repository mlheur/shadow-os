if [ "$*" = "OpenBSD" ]; then
    make OpenBSD && { seergdb --project OpenBSD.seer & GDB=1 IMAGE=OpenBSD.img ./qemu.sh; }
else
    make clean && make && { seergdb --project project.seer & GDB=1 ./qemu.sh; }
fi

