ASM = nasm
SRC_DIR = src
BUILD_DIR = build

.PHONY: all floppy_image kernel bootloader clean always

all: floppy_image

# Floppy image
floppy_image: ${BUILD_DIR}/main_floppy.img

${BUILD_DIR}/main_floppy.img: bootloader kernel
	dd if=/dev/zero of=${BUILD_DIR}/main_floppy.img bs=512 count=2880
	dd if=${BUILD_DIR}/bootloader.bin of=${BUILD_DIR}/main_floppy.img conv=notrunc
	mkfs.fat -F 12 -n "NBOS" ${BUILD_DIR}/main_floppy.img
	mcopy -i ${BUILD_DIR}/main_floppy.img ${BUILD_DIR}/kernel.bin ::kernel.bin

# Bootloader
bootloader: ${BUILD_DIR}/bootloader.bin

${BUILD_DIR}/bootloader.bin: always
	$(ASM) bootloader/boot.asm -f bin -o $(BUILD_DIR)/bootloader.bin

# Kernel
kernel: ${BUILD_DIR}/kernel.bin

${BUILD_DIR}/kernel.bin: always
	$(ASM) kernel/main.asm -f bin -o $(BUILD_DIR)/kernel.bin

# Ensure build directory exists
always:
	mkdir -p ${BUILD_DIR}

# Clean
clean:
	rm -rf ${BUILD_DIR}
