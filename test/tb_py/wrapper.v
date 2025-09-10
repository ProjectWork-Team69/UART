`timescale 1ns / 1ps

module wrapper;

// Parameters
parameter ADDR_WIDTH = 32;
parameter DATA_WIDTH = 32;

// Clock and reset
reg clk;
reg rstn;

// AXI4-Lite Write Slave Interface
reg [ADDR_WIDTH-1:0] s_axil_awaddr;
reg s_axil_awvalid;
wire s_axil_awready;
reg [DATA_WIDTH-1:0] s_axil_wdata;
reg s_axil_wvalid;
wire s_axil_wready;
wire [1:0] s_axil_bresp;
wire s_axil_bvalid;
reg s_axil_bready;

// AXI4-Lite Read Slave Interface
reg [ADDR_WIDTH-1:0] s_axil_araddr;
reg s_axil_arvalid;
wire s_axil_arready;
wire [DATA_WIDTH-1:0] s_axil_rdata;
wire [1:0] s_axil_rresp;
wire s_axil_rvalid;
reg s_axil_rready;

// UART Interface
wire [7:0] uart_tx_data;
wire uart_tx_start;
reg [7:0] uart_rx_data;
reg uart_rx_valid;
reg uart_tx_busy;


// Initialize signals
initial begin
    // AXI Write signals
    s_axil_awaddr = 0;
    s_axil_awvalid = 0;
    s_axil_wdata = 0;
    s_axil_wvalid = 0;
    s_axil_bready = 1;
    
    // AXI Read signals
    s_axil_araddr = 0;
    s_axil_arvalid = 0;
    s_axil_rready = 1;
    
    // UART signals
    uart_rx_data = 0;
    uart_rx_valid = 0;
    uart_tx_busy = 0;
end

// VCD dump
initial begin
    $dumpfile("uart_axil_wrap.vcd");
    $dumpvars(0, wrapper);
end

// Instantiate the DUT (Device Under Test)
uart_axil_wrap #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
) dut (
    // Global Signals
    .clk(clk),
    .rstn(rstn),
    
    // AXI4-Lite Write Slave Interface
    .s_axil_awaddr(s_axil_awaddr),
    .s_axil_awvalid(s_axil_awvalid),
    .s_axil_awready(s_axil_awready),
    .s_axil_wdata(s_axil_wdata),
    .s_axil_wvalid(s_axil_wvalid),
    .s_axil_wready(s_axil_wready),
    .s_axil_bresp(s_axil_bresp),
    .s_axil_bvalid(s_axil_bvalid),
    .s_axil_bready(s_axil_bready),
    
    // AXI4-Lite Read Slave Interface
    .s_axil_araddr(s_axil_araddr),
    .s_axil_arvalid(s_axil_arvalid),
    .s_axil_arready(s_axil_arready),
    .s_axil_rdata(s_axil_rdata),
    .s_axil_rresp(s_axil_rresp),
    .s_axil_rvalid(s_axil_rvalid),
    .s_axil_rready(s_axil_rready),
    
    // UART Interface
    .uart_tx_data(uart_tx_data),
    .uart_tx_start(uart_tx_start),
    .uart_rx_data(uart_rx_data),
    .uart_rx_valid(uart_rx_valid),
    .uart_tx_busy(uart_tx_busy)
);

endmodule