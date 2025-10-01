IMAGE := $(shell cat .image)
GASOPTS := -Isrc/mbr -g -Wa,--32
OBJOPTS := -M att -m i8086

OBJECT := objs/shadow-os.obj

all : ${IMAGE}

clean : 
	rm -f bin/* objs/*.o dumps/*

${IMAGE} : ${OBJECT}
	objcopy -O binary -j .text ${OBJECT}

objs/shadow-os.obj : src/*/*
	gcc ${GASOPTS} -o ${OBJECT} -c src/mbr/mbr.S src/krn/krn.S
	objdump ${OBJOPTS} -d ${OBJECT} > dumps/shadow-os.dump
