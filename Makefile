run : release/shadow-os.fd
	qemu-system-i386 -nographic -fda release/shadow-os.fd

release/shadow-os.fd : src/shadow-boot.asm release
	nasm src/shadow-boot.asm -f bin -o release/shadow-os.fd
	dd if=/dev/zero of=release/shadow-os.fd bs=512 seek=1 count=2879

clean :
	rm -r release

release :
	mkdir release