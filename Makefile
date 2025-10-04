IMAGE := $(shell cat .image)
INCDIR := ./src/include
GASOPTS := -I${INCDIR} -g -Wa,--32 -c
OBJOPTS := -M att -m i8086
LDOPTS  := -s -dT ldscript

OBJECTS := ./objs/mbr.o ./objs/krn.o

all : ${IMAGE}

IMAGE_SECTORS := $(shell ./helpers/get-image-sectors.sh)
PADDING := $(shell ./helpers/get-padding.sh)

padding :
	test -d bin || mkdir bin
	dd if=${IMAGE} of=./bin/image-mbr bs=512 count=1
	objcopy -O binary -j .text ./objs/krn.o ./bin/objcopy-krn
	objcopy -O binary -j .text ./objs/mbr.o ./bin/objcopy-mbr
	./helpers/mkdata.ksh
	dd if=data of=${IMAGE} bs=512 seek=${IMAGE_SECTORS} skip=${IMAGE_SECTORS} count=${PADDING}
	./helpers/compare_mbrs.sh

clean : 
	rm -f ${IMAGE} ./bin/* ./objs/* ./dumps/*

${IMAGE} : ${OBJECTS}
	ld ${LDOPTS} -o ${IMAGE}
	make padding

objs/mbr.o : ${INCDIR}/* ./src/mbr/*
	test -d objs || mkdir objs
	test -d dumps || mkdir dumps
	gcc ${GASOPTS} -o ./objs/mbr.o ./src/mbr/mbr.S && \
	objdump ${OBJOPTS} -d ./objs/mbr.o > ./dumps/mbr.dump && \
	nm -g ./objs/mbr.o > ./objs/mbr.symbols

objs/krn.o : ${INCDIR}/* ./src/krn/*
	test -d objs || mkdir objs
	test -d dumps || mkdir dumps
	gcc ${GASOPTS} -o ./objs/krn.o ./src/krn/krn.S && \
	objdump ${OBJOPTS} -d ./objs/krn.o > ./dumps/krn.dump && \
	nm -g ./objs/krn.o > ./objs/krn.symbols
