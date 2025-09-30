# UART Cocotb Makefile
# Adapted from Alex Forencich template

TOPLEVEL_LANG = verilog

SIM ?= icarus
WAVES ?= 1   # set 1 to generate VCD/FST

COCOTB_HDL_TIMEUNIT = 1ns
COCOTB_HDL_TIMEPRECISION = 1ps

# DUT / top-level module
DUT      = uart_axil_wrap
TOPLEVEL = wrapper     # wrapper module that instantiates uart_axil_wrap
MODULE   = slave            # your python testbench module

# Verilog sources
VERILOG_SOURCES += ../../src/uart_axil_wrap.v ./wrapper.v



# Simulator-specific settings
ifeq ($(SIM), icarus)
	PLUSARGS += -g2012

	# pass parameters to top-level
	COMPILE_ARGS += $(foreach v,$(filter PARAM_%,$(.VARIABLES)),-P $(TOPLEVEL).$(subst PARAM_,,$(v))=$($(v)))

	ifeq ($(WAVES), 1)
		# Use manual wrapper, no auto dump
		# Optionally, you could add auto-generate iverilog_dump.v here if you prefer
	endif
else ifeq ($(SIM), verilator)
	COMPILE_ARGS += -Wno-SELRANGE -Wno-WIDTH
	COMPILE_ARGS += $(foreach v,$(filter PARAM_%,$(.VARIABLES)),-G$(subst PARAM_,,$(v))=$($(v)))

	ifeq ($(WAVES), 1)
		COMPILE_ARGS += --trace-fst
	endif
endif

# include Cocotb standard Makefile
# include Makefile.sim
# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim

# Clean extra files
clean::
	@rm -rf __pycache__
	@rm -rf *.vcd *.fst
	@rm -rf *.o *.out *.vvp
	@rm -rf sim_build
	@rm -rf results.xml

