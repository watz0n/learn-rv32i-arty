include ../../prefix.mk

# Test harness is configured Arty FPGA
#MK_TARGET_PROC  ?= rv32
#SUPERVISOR_MODE="false"

#bmark_timeout ?=1000000
#Need more time for 1port memory on qsort
bmark_timeout ?=2500000

global_asm_tests += \
#	rv32mi-p-csr \
#	rv32mi-p-illegal \

include $(srcDir)/emulator/common/Makefile.include
