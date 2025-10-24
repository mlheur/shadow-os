IMAGE := shadow-os.img

MODULES := mbr krn
BINARIES := $(foreach MODULE,$(MODULES),./bin/$(MODULE))
SOURCES  := $(wildcard ./src/*/*.S)
SOURCES  += $(wildcard ./src/include/*.h)

SUBMAKES    := $(foreach MOD,$(MODULES),./src/$(MOD)/Makefile)
LDSCRIPTS   := $(foreach MOD,$(MODULES),./src/$(MOD)/ld.script)

BUILDDIRS   := bin objs dumps
ARTIFACTS   := $(foreach DIR,$(BUILDDIRS),./$(DIR)/*)

FAKES       := $(foreach ID,2 3 4,fake-hda$(ID).img)

MY_UID		:= $(shell id -u)
MY_GID		:= $(shell id -g)

${IMAGE} : $(SOURCES) $(SUBMAKES) $(LDSCRIPTS) $(BUILDDIRS) $(FAKES)
	@for MOD in $(MODULES); do \
		$(MAKE) $${MOD} -C ./src/$${MOD}/ || exit; \
	done
	cat $(BINARIES) > ${IMAGE} && \
	./helpers/add_padding.ksh ${IMAGE} && \
	cat ${IMAGE} $(FAKES) > new-${IMAGE} && mv new-${IMAGE} ${IMAGE}

$(BUILDDIRS) : ;
	@for DIR in $(BUILDDIRS); do mkdir -p $${DIR} || exit; done

$(FAKES) : ;
	test -d ./mnt || mkdir ./mnt
	@for IMG in $(FAKES); do dd if=/dev/zero of=$${IMG} bs=4k count=256; done
	mkfs -t fat fake-hda2.img
	mkfs -t ext2 fake-hda3.img
	mkfs -t minix fake-hda4.img
	@for IMG in $(FAKES); do \
		sudo mount -o loop $${IMG} ./mnt || exit; \
		sudo ./helpers/mkdata.ksh ./mnt/data.bin; \
		sudo chown -R $(MY_UID):$(MY_GID) ./mnt 2>/dev/null || true; \
		sudo umount ./mnt; \
	done
	rmdir ./mnt

.PHONY : clean
clean :
	@for MOD in $(MODULES); do \
		$(MAKE) clean -C ./src/$${MOD}/; \
	done
	@rm -f ${IMAGE} $(ARTIFACTS) $(FAKES)
