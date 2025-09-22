all : bin/mbr
	objdump -M att -m i8086 -d objs/mbr.o | more

bin/mbr : objs/mbr.o
	objcopy -O binary -j .text objs/mbr.o bin/mbr

objs/mbr.o : src/mbr/mbr.S
	gcc -Wa,--32 -o objs/mbr.o -c src/mbr/mbr.S

clean : 
	rm -f bin/* objs/*.o

install : bin/mbr
	sudo dd if=bin/mbr of=/var/lib/libvirt/images/FourEightySix.img bs=512 count=1
	sudo hexdump -C /var/lib/libvirt/images/FourEightySix.img