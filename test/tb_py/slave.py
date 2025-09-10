import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ClockCycles
from cocotb.binary import BinaryValue
import random

class AXI4LiteMaster:
    def __init__(self, dut):
        self.dut = dut
        
    async def write_transaction(self, address, data, timeout=1000):
        """Perform an AXI4-Lite write transaction with proper handshake"""
        # Initialize signals
        self.dut.s_axil_awvalid.value = 0
        self.dut.s_axil_wvalid.value = 0
        self.dut.s_axil_bready.value = 0
        
        # Wait a cycle to ensure clean state
        await RisingEdge(self.dut.clk)
        
        # Address phase
        self.dut.s_axil_awaddr.value = address
        self.dut.s_axil_awvalid.value = 1
        
        # Wait for awready
        cycles = 0
        while not self.dut.s_axil_awready.value:
            await RisingEdge(self.dut.clk)
            cycles += 1
            if cycles > timeout:
                raise cocotb.result.TestFailure(f"Timeout waiting for awready on write to 0x{address:08x}")
        
        # Address handshake complete
        await RisingEdge(self.dut.clk)
        self.dut.s_axil_awvalid.value = 0
        
        # Data phase
        self.dut.s_axil_wdata.value = data
        self.dut.s_axil_wvalid.value = 1
        
        # Wait for wready
        cycles = 0
        while not self.dut.s_axil_wready.value:
            await RisingEdge(self.dut.clk)
            cycles += 1
            if cycles > timeout:
                raise cocotb.result.TestFailure(f"Timeout waiting for wready on write to 0x{address:08x}")
        
        # Data handshake complete
        await RisingEdge(self.dut.clk)
        self.dut.s_axil_wvalid.value = 0
        
        # Response phase - wait for bvalid
        self.dut.s_axil_bready.value = 1
        
        cycles = 0
        while not self.dut.s_axil_bvalid.value:
            await RisingEdge(self.dut.clk)
            cycles += 1
            if cycles > timeout:
                raise cocotb.result.TestFailure(f"Timeout waiting for bvalid on write to 0x{address:08x}")
        
        resp = int(self.dut.s_axil_bresp.value)
        
        # Response handshake complete
        await RisingEdge(self.dut.clk)
        self.dut.s_axil_bready.value = 0
        
        return resp
    
    async def read_transaction(self, address, timeout=1000):
        """Perform an AXI4-Lite read transaction with proper handshake"""
        # Initialize signals
        self.dut.s_axil_arvalid.value = 0
        self.dut.s_axil_rready.value = 0
        
        # Wait a cycle to ensure clean state
        await RisingEdge(self.dut.clk)
        
        # Address phase
        self.dut.s_axil_araddr.value = address
        self.dut.s_axil_arvalid.value = 1
        
        # Wait for arready
        cycles = 0
        while not self.dut.s_axil_arready.value:
            await RisingEdge(self.dut.clk)
            cycles += 1
            if cycles > timeout:
                raise cocotb.result.TestFailure(f"Timeout waiting for arready on read from 0x{address:08x}")
        
        # Address handshake complete
        await RisingEdge(self.dut.clk)
        self.dut.s_axil_arvalid.value = 0
        
        # Data phase - wait for rvalid
        self.dut.s_axil_rready.value = 1
        
        cycles = 0
        while not self.dut.s_axil_rvalid.value:
            await RisingEdge(self.dut.clk)
            cycles += 1
            if cycles > timeout:
                raise cocotb.result.TestFailure(f"Timeout waiting for rvalid on read from 0x{address:08x}")
        
        data = int(self.dut.s_axil_rdata.value)
        resp = int(self.dut.s_axil_rresp.value)
        
        # Data handshake complete
        await RisingEdge(self.dut.clk)
        self.dut.s_axil_rready.value = 0
        
        return data, resp

async def reset_dut(dut, duration=10):
    """Reset the DUT"""
    dut.rstn.value = 0
    # Initialize all inputs
    dut.s_axil_awaddr.value = 0
    dut.s_axil_awvalid.value = 0
    dut.s_axil_wdata.value = 0
    dut.s_axil_wvalid.value = 0
    dut.s_axil_bready.value = 0
    dut.s_axil_araddr.value = 0
    dut.s_axil_arvalid.value = 0
    dut.s_axil_rready.value = 0
    dut.uart_rx_data.value = 0
    dut.uart_rx_valid.value = 0
    dut.uart_tx_busy.value = 0
    
    await ClockCycles(dut.clk, duration)
    dut.rstn.value = 1
    await ClockCycles(dut.clk, 5)

@cocotb.test()
async def test_basic_functionality(dut):
    """Test basic AXI-Lite functionality"""
    # Start clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset DUT
    await reset_dut(dut)
    
    # Create AXI master
    axi_master = AXI4LiteMaster(dut)
    
    # Test register addresses
    ADDR_TX_DATA = 0x00000000
    ADDR_RX_DATA = 0x00000004
    ADDR_STATUS = 0x00000008
    ADDR_BAUD_SEL = 0x0000000C
    
    # Test 1: Write to BAUD_SEL register
    baud_val = 0x3
    resp = await axi_master.write_transaction(ADDR_BAUD_SEL, baud_val)
    assert resp == 0, f"Expected OKAY response, got {resp}"
    
    # Test 2: Read back BAUD_SEL register
    read_data, read_resp = await axi_master.read_transaction(ADDR_BAUD_SEL)
    assert read_resp == 0, f"Expected OKAY response, got {read_resp}"
    assert read_data == baud_val, f"Expected {baud_val}, got {read_data}"
    
    # Test 3: Write to TX_DATA register
    tx_data = 0x55
    resp = await axi_master.write_transaction(ADDR_TX_DATA, tx_data)
    assert resp == 0, f"Expected OKAY response, got {resp}"
    
    # Check that UART TX signals were set
    await RisingEdge(dut.clk)
    assert dut.uart_tx_data.value == tx_data, f"TX data mismatch: {dut.uart_tx_data.value} != {tx_data}"
    
    # Test 4: Read status register
    status_data, status_resp = await axi_master.read_transaction(ADDR_STATUS)
    assert status_resp == 0, f"Expected OKAY response, got {status_resp}"
    
    # Test 5: Simulate RX data
    rx_data = 0xAA
    dut.uart_rx_data.value = rx_data
    dut.uart_rx_valid.value = 1
    await ClockCycles(dut.clk, 2)
    dut.uart_rx_valid.value = 0
    
    # Read RX_DATA register
    read_rx_data, read_rx_resp = await axi_master.read_transaction(ADDR_RX_DATA)
    assert read_rx_resp == 0, f"Expected OKAY response, got {read_rx_resp}"
    assert read_rx_data == rx_data, f"RX data mismatch: {read_rx_data} != {rx_data}"
    
    dut._log.info("Basic functionality test passed!")

@cocotb.test()
async def test_status_register(dut):
    """Test status register functionality"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    axi_master = AXI4LiteMaster(dut)
    
    ADDR_STATUS = 0x00000008
    
    # Test different status conditions
    test_cases = [
        (0, 0),  # Not busy, no RX data
        (1, 0),  # Busy, no RX data
        (0, 1),  # Not busy, RX data available
        (1, 1),  # Busy, RX data available
    ]
    
    for tx_busy, rx_valid in test_cases:
        dut.uart_tx_busy.value = tx_busy
        dut.uart_rx_valid.value = rx_valid
        await ClockCycles(dut.clk, 2)
        
        status_data, status_resp = await axi_master.read_transaction(ADDR_STATUS)
        assert status_resp == 0, f"Status read failed with response {status_resp}"
        
        expected_status = (rx_valid << 1) | tx_busy
        assert status_data == expected_status, f"Status mismatch: got {status_data}, expected {expected_status}"
    
    dut._log.info("Status register test passed!")

@cocotb.test()
async def test_invalid_address(dut):
    """Test handling of invalid addresses"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    axi_master = AXI4LiteMaster(dut)
    
    # Test invalid addresses
    invalid_addresses = [0x00000010, 0x00000014, 0x00000020, 0xFFFFFFFF]
    
    for addr in invalid_addresses:
        # Test write to invalid address
        resp = await axi_master.write_transaction(addr, 0x12345678)
        assert resp == 2, f"Expected SLVERR for invalid write to 0x{addr:08x}, got {resp}"
        
        # Test read from invalid address
        data, read_resp = await axi_master.read_transaction(addr)
        assert read_resp == 2, f"Expected SLVERR for invalid read from 0x{addr:08x}, got {read_resp}"
    
    dut._log.info("Invalid address test passed!")

@cocotb.test()
async def test_concurrent_operations(dut):
    """Test concurrent read/write operations"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    axi_master = AXI4LiteMaster(dut)
    
    ADDR_TX_DATA = 0x00000000
    ADDR_BAUD_SEL = 0x0000000C
    ADDR_STATUS = 0x00000008
    
    # Set up some RX data
    dut.uart_rx_data.value = 0x42
    dut.uart_rx_valid.value = 1
    
    # Perform multiple operations
    await axi_master.write_transaction(ADDR_BAUD_SEL, 0x2)
    await axi_master.write_transaction(ADDR_TX_DATA, 0x41)
    
    # Check results
    baud_data, _ = await axi_master.read_transaction(ADDR_BAUD_SEL)
    assert baud_data == 0x2, f"Baud rate not set correctly: {baud_data}"
    
    rx_data, _ = await axi_master.read_transaction(0x00000004)  # RX_DATA
    assert rx_data == 0x42, f"RX data incorrect: {rx_data:02x}"
    
    dut.uart_rx_valid.value = 0
    dut._log.info("Concurrent operations test passed!")

@cocotb.test()
async def test_register_coverage(dut):
    """Test all registers in the address map"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    axi_master = AXI4LiteMaster(dut)
    
    # Test all valid registers
    registers = {
        0x00000000: ("TX_DATA", "write"),
        0x00000004: ("RX_DATA", "read"),
        0x00000008: ("STATUS", "read"),
        0x0000000C: ("BAUD_SEL", "read-write")
    }
    
    for addr, (name, access) in registers.items():
        if access in ["write", "read-write"]:
            test_data = random.randint(0, 255) if name == "TX_DATA" else random.randint(0, 7)
            resp = await axi_master.write_transaction(addr, test_data)
            assert resp == 0, f"Write to {name} failed with response {resp}"
        
        if access in ["read", "read-write"]:
            if name == "RX_DATA":
                # Provide some RX data
                rx_test_data = random.randint(0, 255)
                dut.uart_rx_data.value = rx_test_data
                dut.uart_rx_valid.value = 1
                await ClockCycles(dut.clk, 2)
            
            data, resp = await axi_master.read_transaction(addr)
            assert resp == 0, f"Read from {name} failed with response {resp}"
            
            if name == "RX_DATA":
                assert data == rx_test_data, f"RX_DATA read mismatch: {data} != {rx_test_data}"
                dut.uart_rx_valid.value = 0
                
    
    dut._log.info("Register coverage test passed!")

# Run the tests
if __name__ == "__main__":
    # Simple test execution
    test_basic_functionality()
    test_status_register()
    test_invalid_address()
    test_concurrent_operations()
    test_register_coverage()
