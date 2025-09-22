all : mbr
	objdump -M att -m i8086 -d objs/mbr.o

mbr : objs/mbr.o
	objcopy -O binary -j .text objs/mbr.o mbr

objs/mbr.o : src/mbr/mbr.S
	gcc -o objs/mbr.o -c src/mbr/mbr.S

clean : 
	rm -f mbr objs/*.o

install : all
	sudo dd if=mbr of=/var/lib/libvirt/images/FourEightySix.img bs=512 count=1
	sudo hexdump -C /var/lib/libvirt/images/FourEightySix.img