IMAGE := $(shell cat .image)

MODULES := mbr krn
BINARIES := $(foreach MODULE,$(MODULES),./bin/$(MODULE))
SOURCES  := $(wildcard ./src/*/*.S)
SOURCES  += $(wildcard ./src/include/*.h)

SUBMAKES    := $(foreach MOD,$(MODULES),./src/$(MOD)/Makefile)

${IMAGE} : $(BINARIES)
	cat $(BINARIES) > ${IMAGE} && \
	./helpers/add_padding.ksh ${IMAGE} && \
	cat ${IMAGE} fake-hda[234].img > new-${IMAGE} && mv new-${IMAGE} ${IMAGE}

$(BINARIES) : $(SOURCES) $(SUBMAKES)
	for MOD in $(MODULES); do $(MAKE) $$MOD -C ./src/$${MOD}/ || exit; done

.PHONY : clean
clean :
	for MOD in $(MODULES); do $(MAKE) clean -C ./src/$${MOD}/; done
	rm -f ${IMAGE}
