# SPDX-License-Identifier: Zlib
#
# Build the example. The toolchain lives in the image (see Dockerfile), so this
# is run inside it:
#
#   docker build -t ds-example .
#   docker run --rm -v "$PWD:/work" ds-example make
#
# Add more C files by listing their objects in OBJS.

# BlocksDS paths inside the image.
export BLOCKSDS            ?= /opt/wonderful/thirdparty/blocksds/core
export WONDERFUL_TOOLCHAIN ?= /opt/wonderful
ARM_NONE_EABI_PATH         ?= $(WONDERFUL_TOOLCHAIN)/toolchain/gcc-arm-none-eabi/bin/

PREFIX  := $(ARM_NONE_EABI_PATH)arm-none-eabi-
CC      := $(PREFIX)gcc
ARCH    := -mthumb -mcpu=arm946e-s+nofp
SPECS   := $(BLOCKSDS)/sys/crts/ds_arm9.specs
ARM7ELF ?= $(BLOCKSDS)/sys/arm7/main_core/arm7_minimal.elf

TARGET  := hello
OBJS    := main.o

# The title ndstool writes into the header: 12 characters maximum.
TITLE   := $(TARGET)

CFLAGS  := $(ARCH) -O2 -specs=$(SPECS) -DARM9 -D__NDS__ -D__BLOCKSDS__ \
           -I$(BLOCKSDS)/libs/libnds/include -Wall
LDFLAGS := $(ARCH) -specs=$(SPECS) -L$(BLOCKSDS)/libs/libnds/lib \
           -Wl,--start-group -lnds9 -lc -Wl,--end-group

all: $(TARGET).nds

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

$(TARGET).elf: $(OBJS)
	$(CC) -o $@ $^ $(LDFLAGS)

$(TARGET).nds: $(TARGET).elf
	$(BLOCKSDS)/tools/ndstool/ndstool -c $@ \
		-7 $(ARM7ELF) -9 $< \
		-g RETR 01 "$(TITLE)"

clean:
	rm -f $(OBJS) $(TARGET).elf $(TARGET).nds

.PHONY: all clean
