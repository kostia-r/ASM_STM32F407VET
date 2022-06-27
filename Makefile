######################################
TARGET = STM32F407VET_BLINK_ASM
######################################
BUILD_DIR = build
######################################
SOURCES = $(wildcard ./src/*.asm)
######################################
PREFIX = arm-none-eabi-
CC = $(PREFIX)gcc
AS = $(PREFIX)as
LD = $(PREFIX)ld
CP = $(PREFIX)objcopy
OBJDUMP = $(PREFIX)objdump
HEX = $(CP) -O ihex
BIN = $(CP) -O binary
######################################
LDSCRIPT = STM32F407VETx_linker_script.ld
######################################
# default action: build all
all: $(BUILD_DIR)/$(TARGET).elf $(BUILD_DIR)/$(TARGET).list $(BUILD_DIR)/$(TARGET).hex $(BUILD_DIR)/$(TARGET).bin
	rm -f $(BUILD_DIR)/*.o
#######################################
# build the application
#######################################
# list of objects
OBJECTS = $(addprefix $(BUILD_DIR)/,$(notdir $(SOURCES:.asm=.o)))
vpath %.asm $(sort $(dir $(SOURCES)))

$(BUILD_DIR)/%.o: %.asm Makefile | $(BUILD_DIR)
	$(AS) $< -g -o $@

$(BUILD_DIR)/$(TARGET).elf: $(OBJECTS) Makefile
	$(LD) $(OBJECTS) -T$(LDSCRIPT) -o $@
	rm -f $(BUILD_DIR)/*.o

$(BUILD_DIR)/%.list: $(BUILD_DIR)/%.elf | $(BUILD_DIR)
	$(OBJDUMP) -D $< > $@
	rm -f $(BUILD_DIR)/*.o

$(BUILD_DIR)/%.hex: $(BUILD_DIR)/%.elf | $(BUILD_DIR)
	$(HEX) $< $@
	rm -f $(BUILD_DIR)/*.o

$(BUILD_DIR)/%.bin: $(BUILD_DIR)/%.elf | $(BUILD_DIR)
	$(BIN) $< $@
	rm -f $(BUILD_DIR)/*.o

$(BUILD_DIR):
	mkdir $@
#######################################
# clean up
#######################################
clean:
	-rm -fR $(BUILD_DIR)
#######################################
# FLash with ST-LINK
#######################################
flash: $(BUILD_DIR)/$(TARGET).bin
	st-flash --reset write $< 0x8000000
#######################################
# FLash with ST-LINK
#######################################
flashSt: $(BUILD_DIR)/$(TARGET).bin
	st-flash --reset write $< 0x8000000
#######################################
# FLash with Openocd
#######################################
flashOpenOcd: all
	openocd -f interface/stlink.cfg -f target/stm32f4x.cfg -c "program $(BUILD_DIR)/$(TARGET).elf verify reset exit"
#######################################
# dependencies
#######################################
-include $(wildcard $(BUILD_DIR)/*.d)

# *** EOF ***
