IMAGE := $(shell cat .image)
GASOPTS := -Isrc/mbr -g -Wa,--32
OBJOPTS := -M att -m i8086

all : ${IMAGE}

clean : 
	rm -f bin/* objs/*.o dumps/*

${IMAGE} : bin/mbr bin/krn
	dd of=${IMAGE} bs=512 seek=0 if=bin/mbr count=1
	dd of=${IMAGE} bs=512 seek=1 if=bin/krn

bin/mbr : objs/mbr.o
	test -d bin || mkdir bin
	objcopy -O binary -j .text objs/mbr.o bin/mbr

bin/krn : objs/krn.o
	test -d bin || mkdir bin
	objcopy -O binary -j .text objs/krn.o bin/krn

objs/mbr.o : src/mbr/*
	test -d objs || mkdir objs
	test -d dumps || mkdir dumps
	gcc ${GASOPTS} -o objs/mbr.o -c src/mbr/mbr.S
	objdump ${OBJOPTS} -d objs/mbr.o > dumps/mbr.dump
	nm -g objs/mbr.o > objs/mbr.symbols

objs/krn.o : src/krn/* objs/mbr.o
	test -d objs || mkdir objs
	gcc ${GASOPTS} -o objs/krn.o -c src/krn/krn.S
	objdump ${OBJOPTS} -d objs/krn.o > dumps/krn.dump
	nm -g objs/krn.o > objs/krn.symbols
