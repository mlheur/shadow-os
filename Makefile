IMAGE := $(shell cat .image)
INCDIR := ./src/include
GASOPTS := -I${INCDIR} -g -Wa,--32 -c
OBJOPTS := -M att -m i8086

LDOPTS  := -static -s -dT ./ld.script -Map=./dumps/final_linker_symbols.map

OBJECTS := ./objs/mbr.o ./objs/krn.o


all : ${IMAGE}

clean : 
	rm -f ${IMAGE} ./bin/* ./objs/* ./dumps/*

${IMAGE} : ${OBJECTS}
	ld ${LDOPTS} -o ${IMAGE} ${OBJECTS} && \
	./helpers/add_padding.ksh ${IMAGE} && \
	cat ${IMAGE} fake-hda2.img > new-${IMAGE} && mv new-${IMAGE} ${IMAGE}

objs/mbr.o : dirs ${INCDIR}/* ./src/mbr/*
	gcc ${GASOPTS} -o ./objs/mbr.o ./src/mbr/mbr.S && \
	objcopy -O binary -j .text ./objs/mbr.o ./bin/objcopy-mbr && \
	objdump ${OBJOPTS} -d ./objs/mbr.o > ./dumps/mbr.dump && \
	nm -g ./objs/mbr.o > ./objs/mbr.symbols

objs/krn.o : dirs ${INCDIR}/* ./src/krn/*
	gcc ${GASOPTS} -o ./objs/krn.o ./src/krn/krn.S && \
	objcopy -O binary -j .text ./objs/krn.o ./bin/objcopy-krn && \
	objdump -M att -m i386 -d ./objs/krn.o > ./dumps/krn.dump && \
	nm -g ./objs/krn.o > ./objs/krn.symbols

dirs : objs dumps bin
	test -d objs || mkdir objs
	test -d dumps || mkdir dumps
	test -d bin || mkdir bin
