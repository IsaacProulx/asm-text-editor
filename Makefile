#TODO: make this more customizable (use variables for assembler, linker, debug info, etc)

TARGET_EXEC := editor
SRC_DIR := ./src
BUILD_DIR := ./build
OBJS := $(addprefix $(BUILD_DIR)/,main.o)


$(BUILD_DIR)/$(TARGET_EXEC) : $(OBJS)
	ld $(OBJS) -o $@

$(BUILD_DIR)/%.o : $(SRC_DIR)/%.asm | $(BUILD_DIR)
	nasm $< -felf64 -g -F stabs -o $@ -i $(SRC_DIR) 

$(BUILD_DIR):
	mkdir $(BUILD_DIR)

.PHONY: clean
clean:
	rm -rf $(BUILD_DIR)/
