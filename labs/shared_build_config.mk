#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

# Ensure MODULES is defined
export MODULES := $(abspath $(CURDIR)/../../submodules)

# Configuration and path settings
export RUCKUS_DIR := $(MODULES)/ruckus
export TOP_DIR := $(abspath $(CURDIR))
export PROJ_DIR := $(TOP_DIR)
export OUT_DIR := $(PROJ_DIR)/build
export RUCKUS_PROC_TCL := $(RUCKUS_DIR)/ghdl/proc.tcl

# Bypass Xilinx specific code
export VIVADO_VERSION := -1.0

# Override the submodule check
export OVERRIDE_SUBMODULE_LOCKS := 1

# GHDL build flags
GHDLFLAGS := --workdir=$(OUT_DIR) --ieee=synopsys -fexplicit \
             -frelaxed-rules --warn-no-library

# Include the ruckus shared Makefile header
include $(RUCKUS_DIR)/system_shared.mk

# Override build string
export GHDL_VERSION := $(shell ghdl -v 2>&1 | head -n 1)
export BUILD_STRING := "$(PROJECT): $(GHDL_VERSION), $(BUILD_SYS_NAME) ($(BUILD_SVR_TYPE)), Built $(BUILD_DATE) by $(BUILD_USER)"

.PHONY: all test src syntax mkdir_build

all: syntax

# Ensure the build directory exists
mkdir_build:
	@mkdir -p $(OUT_DIR)

# Test variables
test:
	@echo "PWD: $(CURDIR)"
	@echo "MODULES: $(MODULES)"
	@echo "RUCKUS_DIR: $(RUCKUS_DIR)"
	@echo "PROJ_DIR: $(PROJ_DIR)"
	@echo "PRJ_VERSION: $(PRJ_VERSION)"
	@echo "OUT_DIR: $(OUT_DIR)"
	@echo "RUCKUS_PROC_TCL: $(RUCKUS_PROC_TCL)"
	@echo "VIVADO_VERSION: $(VIVADO_VERSION)"

# Load source code into GHDL
src: mkdir_build
	@echo "VHDL Source Code Loading"
	@$(RUCKUS_DIR)/ghdl/import.tcl >/dev/null 2>&1

# VHDL syntax checking
syntax: src
	@echo "VHDL Syntax Checking"
	@ghdl -i $(GHDLFLAGS) --work=surf   $(PROJ_DIR)/build/SRC_VHDL/surf/*
	@ghdl -i $(GHDLFLAGS) --work=ruckus $(PROJ_DIR)/build/SRC_VHDL/ruckus/*
	@ghdl -i $(GHDLFLAGS) --work=work   $(PROJ_DIR)/build/SRC_VHDL/work/*
