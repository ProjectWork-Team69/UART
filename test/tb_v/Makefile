# Makefile for Verilog testbenches
# Place this file in test/tb_v/

# Directories
SRC_DIR = ../../src
TB_DIR = .
BUILD_DIR = build

# Simulator
SIM = iverilog
VVP = vvp
GTKWAVE = gtkwave

# Compiler flags
IVERILOG_FLAGS = -g2012 -Wall
VVP_FLAGS = 

# Source files
BAUD_RX_GEN = $(SRC_DIR)/baud_rx_gen.v
BAUD_TX_GEN = $(SRC_DIR)/baud_tx_gen.v
RX_UART = $(SRC_DIR)/RX_uart.v
TX_UART = $(SRC_DIR)/TX_uart.v

# Testbench files
TB_RX = $(TB_DIR)/tb_rx.v
TB_TX = $(TB_DIR)/tb_tx.v

# Build targets
RX_VVP = $(BUILD_DIR)/tb_rx.vvp
TX_VVP = $(BUILD_DIR)/tb_tx.vvp

# VCD files
RX_VCD = $(BUILD_DIR)/tb_rx.vcd
TX_VCD = $(BUILD_DIR)/tb_tx.vcd

# Default target
all: test_rx test_tx

# Create build directory
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Compile RX testbench
$(RX_VVP): $(RX_UART) $(BAUD_RX_GEN) $(TB_RX) | $(BUILD_DIR)
	$(SIM) $(IVERILOG_FLAGS) -o $@ $(BAUD_RX_GEN) $(RX_UART) $(TB_RX)

# Compile TX testbench  
$(TX_VVP): $(TX_UART) $(BAUD_TX_GEN) $(TB_TX) | $(BUILD_DIR)
	$(SIM) $(IVERILOG_FLAGS) -o $@ $(BAUD_TX_GEN) $(TX_UART) $(TB_TX)

# Run RX test
test_rx: $(RX_VVP)
	cd $(BUILD_DIR) && $(VVP) $(VVP_FLAGS) tb_rx.vvp

# Run TX test
test_tx: $(TX_VVP)
	cd $(BUILD_DIR) && $(VVP) $(VVP_FLAGS) tb_tx.vvp

# Run both tests
test: test_rx test_tx

# View RX waveform
wave_rx: $(RX_VCD)
	$(GTKWAVE) $(RX_VCD)

# View TX waveform
wave_tx: $(TX_VCD)
	$(GTKWAVE) $(TX_VCD)

# Generate VCD files (if testbenches support it)
$(RX_VCD): test_rx
$(TX_VCD): test_tx

# Clean build files
clean:
	rm -rf $(BUILD_DIR)

# Clean everything including VCD files
distclean: clean
	rm -f *.vcd *.lxt

# Help target
help:
	@echo "Available targets:"
	@echo "  all       - Compile and run both testbenches"
	@echo "  test      - Run both testbenches"
	@echo "  test_rx   - Run RX UART testbench"
	@echo "  test_tx   - Run TX UART testbench"
	@echo "  wave_rx   - View RX waveform with GTKWave"
	@echo "  wave_tx   - View TX waveform with GTKWave"
	@echo "  clean     - Remove build files"
	@echo "  distclean - Remove all generated files"
	@echo "  help      - Show this help"

# Phony targets
.PHONY: all test test_rx test_tx run_rx run_tx wave_rx wave_tx clean distclean help