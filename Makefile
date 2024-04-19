EMUL      = "qemu-system-i386"
BOOT      = "release/shadow-boot.bin"
BIOS      = "release/shadow-bios.bin"

run : ${BOOT}
	${EMUL} -nographic -fda ${BOOT}

run-bios : ${BOOT} ${BIOS}
	${EMUL} -nographic -d cpu -bios ${BIOS} -singlestep -D q.log -fda ${BOOT}


${BIOS} : build/shadow-bios.o
	test -d release || mkdir -p release
	cp $< $@


${BOOT} : build/shadow-boot.o
	test -d release || mkdir -p release
	dd if=$<        of=$@ bs=512        count=1
	dd if=/dev/zero of=$@ bs=512 seek=1 count=2879


build/%.o: src/%.asm Makefile
	test -d build || mkdir build
	nasm $< -f bin -o $@

clean :
	rm -fr build release
