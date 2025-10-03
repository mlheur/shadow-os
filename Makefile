IMAGE := $(shell cat .image)
INCDIR := ./src/include
GASOPTS := -I${INCDIR} -g -Wa,--32 -c
OBJOPTS := -M att -m i8086
LDOPTS  := -s -m elf_i386 --oformat binary -e _start -Ttext 0

OBJECTS := ./objs/mbr.o ./objs/krn.o

all : ${IMAGE}

clean : 
	rm -f ${IMAGE} ./bin/* ./objs/* ./dumps/*

${IMAGE} : ${OBJECTS}
	ld ${LDOPTS} -o ${IMAGE} ${OBJECTS}
	test -d bin || mkdir bin
	dd if=${IMAGE} of=./bin/image-mbr bs=512 count=1
	objcopy -O binary -j .text objs/krn.o bin/objcopy-krn
	objcopy -O binary -j .text objs/mbr.o bin/objcopy-mbr

objs/mbr.o : ${INCDIR}/* ./src/mbr/*
	test -d objs || mkdir objs
	test -d dumps || mkdir dumps
	gcc ${GASOPTS} -o objs/mbr.o src/mbr/mbr.S && \
	objdump ${OBJOPTS} -d objs/mbr.o > dumps/mbr.dump && \
	nm -g objs/mbr.o > objs/mbr.symbols

objs/krn.o : ${INCDIR}/* ./src/krn/*
	test -d objs || mkdir objs
	test -d dumps || mkdir dumps
	gcc ${GASOPTS} -o objs/krn.o src/krn/krn.S && \
	objdump ${OBJOPTS} -d objs/krn.o > dumps/krn.dump && \
	nm -g objs/krn.o > objs/krn.symbols
