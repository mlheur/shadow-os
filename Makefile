IMAGE := $(shell cat .image)

all : bin/mbr

bin/mbr : objs/mbr.o
	test -d dumps || mkdir dumps
	test -d bin || mkdir bin
	objcopy -O binary -j .text objs/mbr.o bin/mbr
	objdump -M att -m i8086 -d objs/mbr.o > dumps/mbr.dump

objs/mbr.o : src/mbr/*
	test -d objs || mkdir objs
	gcc -g -Wa,--32 -o objs/mbr.o -c src/mbr/mbr.S

clean : 
	rm -f bin/* objs/*.o dumps/*

install : bin/mbr
	dd if=bin/mbr of=${IMAGE} bs=512 count=2
	dd if=data skip=2 of=${IMAGE} bs=512 seek=2 count=126