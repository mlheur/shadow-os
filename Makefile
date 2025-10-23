IMAGE := $(shell cat .image)

MODULES := mbr krn
BINARIES := $(foreach MODULE,$(MODULES),./bin/$(MODULE))
SOURCES  := $(wildcard ./src/*/*.S)
SOURCES  += $(wildcard ./src/include/*.h)

LDSCRIPT 	:= ./ld.script

AS       	:= gcc
ASFLAGS  	:= -I$(INCDIR) -g -Wa,--32 -c
LD       	:= ld
LDFLAGS  	:= -static -s -dT $(LDSCRIPT)
CC			:= ld

${IMAGE} : $(BINARIES)
	cat $(BINARIES) > ${IMAGE} && \
	./helpers/add_padding.ksh ${IMAGE} && \
	cat ${IMAGE} fake-hda[234].img > new-${IMAGE} && mv new-${IMAGE} ${IMAGE}

$(BINARIES) : $(SOURCES)
	for MOD in $(MODULES); do $(MAKE) -C ./src/$${MOD}/; done

.PHONY : clean
clean :
	for MOD in $(MODULES); do $(MAKE) clean -C ./src/$${MOD}; done
	rm -f ${IMAGE}
