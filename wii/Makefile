.SUFFIXES:

ifeq ($(strip $(DEVKITPPC)),)
$(error DEVKITPPC is not set; source wii/env.sh first)
endif

include $(DEVKITPPC)/wii_rules

TARGET := netsurf-wii-smoke
BUILD := build
SOURCES := source
DEPS_ROOT ?= $(CURDIR)/.deps
LIBNSFB_ROOT := $(DEPS_ROOT)/libnsfb
NETWORK_ROOT := $(DEPS_ROOT)/network
INCLUDES := $(NETWORK_ROOT)/include $(LIBNSFB_ROOT)/include

CFLAGS := -g -O2 -Wall -Wextra -Werror $(MACHDEP) $(INCLUDE)
LDFLAGS := -g $(MACHDEP) -Wl,-Map,$(notdir $@).map
LIBS := -Wl,--whole-archive -lnsfb -Wl,--no-whole-archive \
	-lcurl -lmbedtls -lmbedx509 -lmbedcrypto -lz -lwiisocket \
	-lSDLmain -lSDL -laesnd -lwiiuse -lbte -lwiikeyboard -lfat \
	-lopengx -logc -lm
LIBDIRS := $(LIBNSFB_ROOT)/prefix $(NETWORK_ROOT) \
	/opt/devkitpro/portlibs/wii \
	/opt/devkitpro/portlibs/ppc

ifneq ($(BUILD),$(notdir $(CURDIR)))

export OUTPUT := $(CURDIR)/$(TARGET)
export VPATH := $(foreach dir,$(SOURCES),$(CURDIR)/$(dir))
export DEPSDIR := $(CURDIR)/$(BUILD)

CFILES := $(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.c)))
export OFILES := $(CFILES:.c=.o)
export HFILES :=
export INCLUDE := $(foreach dir,$(INCLUDES),-I$(dir)) \
	$(foreach dir,$(LIBDIRS),-I$(dir)/include) \
	-I$(CURDIR)/$(BUILD) -I$(LIBOGC_INC)
export LIBPATHS := -L$(LIBOGC_LIB) \
	$(foreach dir,$(LIBDIRS),-L$(dir)/lib)
export LD := $(CC)

.PHONY: all clean package run
all: check-deps $(BUILD)

check-deps:
	@test -f $(LIBNSFB_ROOT)/prefix/lib/libnsfb.a || \
		(echo "Run ./bootstrap-deps.sh first"; exit 1)
	@test -f $(NETWORK_ROOT)/lib/libcurl.a || \
		(echo "Run ./bootstrap-deps.sh first"; exit 1)

$(BUILD):
	@mkdir -p $@
	@$(MAKE) --no-print-directory -C $(BUILD) -f $(CURDIR)/Makefile

clean:
	@rm -rf $(BUILD) $(OUTPUT).elf $(OUTPUT).dol

package: all
	@mkdir -p dist/apps/netsurf
	@cp $(OUTPUT).dol dist/apps/netsurf/boot.dol
	@cp meta.xml cacert.pem dist/apps/netsurf/
	@echo "Packaged dist/apps/netsurf"

run: all
	wiiload $(TARGET).dol

else

DEPENDS := $(OFILES:.o=.d)
$(OUTPUT).dol: $(OUTPUT).elf
$(OUTPUT).elf: $(OFILES)
-include $(DEPENDS)

endif
