`timescale 1ns / 1ps

module uart_axil_wrap #
(
    parameter ADDR_WIDTH = 32,    // Width of address bus in bits
    parameter DATA_WIDTH = 32     // Width of data bus in bits
)
(
    // Global Signals
    input wire clk,
    input wire rstn,

    // AXI4-Lite Write Slave Interface
    input wire [ADDR_WIDTH-1:0] s_axil_awaddr,
    input wire s_axil_awvalid,
    output wire s_axil_awready,
    input wire [DATA_WIDTH-1:0] s_axil_wdata,
    input wire s_axil_wvalid,
    output wire s_axil_wready,
    output wire [1:0] s_axil_bresp,
    output wire s_axil_bvalid,
    input wire s_axil_bready,

    // AXI4-Lite Read Slave Interface
    input wire [ADDR_WIDTH-1:0] s_axil_araddr,
    input wire s_axil_arvalid,
    output wire s_axil_arready,
    output wire [DATA_WIDTH-1:0] s_axil_rdata,
    output wire [1:0] s_axil_rresp,
    output wire s_axil_rvalid,
    input wire s_axil_rready,

    // UART Interface
    output wire [7:0] uart_tx_data,
    output wire uart_tx_start,
    input wire [7:0] uart_rx_data,
    input wire uart_rx_valid,
    input wire uart_tx_busy
);

// Register Addresses
localparam ADDR_TX_DATA = 32'h0000_0000;
localparam ADDR_RX_DATA = 32'h0000_0004;
localparam ADDR_STATUS  = 32'h0000_0008;
localparam ADDR_BAUD_SEL = 32'h0000_000C;

// Write FSM States
localparam [1:0] STATE_IDLE_WR = 2'd0,
                 STATE_DATA_WR = 2'd1,
                 STATE_RESP_WR = 2'd2;

// Read FSM States
localparam [1:0] STATE_IDLE_RD = 2'd0,
                 STATE_DATA_RD = 2'd1,
                 STATE_RESP_RD = 2'd2;

// Write FSM Registers
reg [1:0] state_wr_reg, state_wr_next;
reg s_axil_awready_reg, s_axil_awready_next;
reg s_axil_wready_reg, s_axil_wready_next;
reg [1:0] s_axil_bresp_reg, s_axil_bresp_next;
reg s_axil_bvalid_reg, s_axil_bvalid_next;

// Read FSM Registers
reg [1:0] state_rd_reg, state_rd_next;
reg s_axil_arready_reg, s_axil_arready_next;
reg [DATA_WIDTH-1:0] s_axil_rdata_reg, s_axil_rdata_next;
reg [1:0] s_axil_rresp_reg, s_axil_rresp_next;
reg s_axil_rvalid_reg, s_axil_rvalid_next;

// UART Registers
reg [7:0] uart_tx_data_reg, uart_tx_data_next;
reg uart_tx_start_reg, uart_tx_start_next;
reg [2:0] reg_baud_sel, reg_baud_sel_next;
reg uart_rx_valid_reg, uart_rx_valid_next;
reg rx_data_clear_next;

// Latched Addresses
reg [ADDR_WIDTH-1:0] s_axil_awaddr_latched_reg, s_axil_awaddr_latched_next;
reg [ADDR_WIDTH-1:0] s_axil_araddr_latched_reg, s_axil_araddr_latched_next;

// Output Assignments
assign s_axil_awready = s_axil_awready_reg;
assign s_axil_wready = s_axil_wready_reg;
assign s_axil_bresp = s_axil_bresp_reg;
assign s_axil_bvalid = s_axil_bvalid_reg;

assign s_axil_arready = s_axil_arready_reg;
assign s_axil_rdata = s_axil_rdata_reg;
assign s_axil_rresp = s_axil_rresp_reg;
assign s_axil_rvalid = s_axil_rvalid_reg;

assign uart_tx_data = uart_tx_data_reg;
assign uart_tx_start = uart_tx_start_reg;

// Write FSM Combinational Logic
always @* begin
    // Default assignments
    state_wr_next = state_wr_reg;
    s_axil_awready_next = 1'b0;
    s_axil_wready_next = 1'b0;
    s_axil_bresp_next = s_axil_bresp_reg;
    s_axil_bvalid_next = s_axil_bvalid_reg && !s_axil_bready;

    uart_tx_data_next = uart_tx_data_reg;
    uart_tx_start_next = 1'b0;
    reg_baud_sel_next = reg_baud_sel;
    s_axil_awaddr_latched_next = s_axil_awaddr_latched_reg;

    case (state_wr_reg)
        STATE_IDLE_WR: begin
            s_axil_awready_next = 1'b1;
            if (s_axil_awvalid && s_axil_awready) begin
                s_axil_awready_next = 1'b0;
                s_axil_awaddr_latched_next = s_axil_awaddr;
                state_wr_next = STATE_DATA_WR;
            end
        end

        STATE_DATA_WR: begin
            s_axil_wready_next = 1'b1;
            if (s_axil_wvalid && s_axil_wready) begin
                s_axil_wready_next = 1'b0;
                case (s_axil_awaddr_latched_reg)
                    ADDR_TX_DATA: begin
                        uart_tx_data_next = s_axil_wdata[7:0];
                        uart_tx_start_next = 1'b1;
                    end
                    ADDR_BAUD_SEL: begin
                        reg_baud_sel_next = s_axil_wdata[2:0];
                    end
                    default: begin
                        s_axil_bresp_next = 2'b10; // SLVERR
                    end
                endcase
                state_wr_next = STATE_RESP_WR;
            end
        end

        STATE_RESP_WR: begin
            s_axil_bvalid_next = 1'b1;
            if (s_axil_bready) begin
                s_axil_bvalid_next = 1'b0;
                state_wr_next = STATE_IDLE_WR;
            end
        end
    endcase
end

// Write FSM Sequential Logic
always @(posedge clk) begin
    if (!rstn) begin
        state_wr_reg <= STATE_IDLE_WR;
        s_axil_awready_reg <= 1'b0;
        s_axil_wready_reg <= 1'b0;
        s_axil_bresp_reg <= 2'b00;
        s_axil_bvalid_reg <= 1'b0;
        uart_tx_data_reg <= 8'b0;
        uart_tx_start_reg <= 1'b0;
        reg_baud_sel <= 3'b0;
        s_axil_awaddr_latched_reg <= 0;
    end else begin
        state_wr_reg <= state_wr_next;
        s_axil_awready_reg <= s_axil_awready_next;
        s_axil_wready_reg <= s_axil_wready_next;
        s_axil_bresp_reg <= s_axil_bresp_next;
        s_axil_bvalid_reg <= s_axil_bvalid_next;
        uart_tx_data_reg <= uart_tx_data_next;
        uart_tx_start_reg <= uart_tx_start_next;
        reg_baud_sel <= reg_baud_sel_next;
        s_axil_awaddr_latched_reg <= s_axil_awaddr_latched_next;
    end
end

// Read FSM Combinational Logic
always @* begin
    // Default assignments
    state_rd_next = state_rd_reg;
    s_axil_arready_next = 1'b0;
    s_axil_rdata_next = s_axil_rdata_reg;
    s_axil_rresp_next = s_axil_rresp_reg;
    s_axil_rvalid_next = s_axil_rvalid_reg && !s_axil_rready;
    s_axil_araddr_latched_next = s_axil_araddr_latched_reg;
    rx_data_clear_next = 1'b0;

    case (state_rd_reg)
        STATE_IDLE_RD: begin
            s_axil_arready_next = 1'b1;
            if (s_axil_arvalid && s_axil_arready) begin
                s_axil_arready_next = 1'b0;
                s_axil_araddr_latched_next = s_axil_araddr;
                state_rd_next = STATE_DATA_RD;
            end
        end

        STATE_DATA_RD: begin
            case (s_axil_araddr_latched_reg)
                ADDR_RX_DATA: begin
                    s_axil_rdata_next = uart_rx_data;
                    s_axil_rresp_next = 2'b00;
                    rx_data_clear_next = 1'b1;
                end
                ADDR_STATUS: begin
                    s_axil_rdata_next = {30'b0, uart_rx_valid, uart_tx_busy};
                    s_axil_rresp_next = 2'b00;
                end
                ADDR_BAUD_SEL: begin
                    s_axil_rdata_next = {29'b0, reg_baud_sel};
                    s_axil_rresp_next = 2'b00;
                end
                default: begin
                    s_axil_rdata_next = 0;
                    s_axil_rresp_next = 2'b10;
                end
            endcase
            s_axil_rvalid_next = 1'b1;
            state_rd_next = STATE_RESP_RD;
        end

        STATE_RESP_RD: begin
            s_axil_rvalid_next = 1'b1;
            if (s_axil_rready) begin
                s_axil_rvalid_next = 1'b0;
                state_rd_next = STATE_IDLE_RD;
            end
        end
    endcase
end

// Read FSM Sequential Logic
always @(posedge clk) begin
    if (!rstn) begin
        state_rd_reg <= STATE_IDLE_RD;
        s_axil_arready_reg <= 1'b0;
        s_axil_rdata_reg <= 0;
        s_axil_rresp_reg <= 2'b00;
        s_axil_rvalid_reg <= 1'b0;
        s_axil_araddr_latched_reg <= 0;
        uart_rx_valid_reg <= 1'b0;
    end else begin
        state_rd_reg <= state_rd_next;
        s_axil_arready_reg <= s_axil_arready_next;
        s_axil_rdata_reg <= s_axil_rdata_next;
        s_axil_rresp_reg <= s_axil_rresp_next;
        s_axil_rvalid_reg <= s_axil_rvalid_next;
        s_axil_araddr_latched_reg <= s_axil_araddr_latched_next;
        if (rx_data_clear_next) begin
            uart_rx_valid_reg <= 1'b0;
        end else if (uart_rx_valid) begin
            uart_rx_valid_reg <= 1'b1;
        end
    end
end
    /////////////////////////////////////////////////////////////////
    // INSTANTIATE THE UART CORE MODULES
    /////////////////////////////////////////////////////////////////

//	 module test_tx (
//    input clk, // 50 MHz
//    input rst_n,
//    input start, // Initiate tx
//    input baud_sel, // Baud rate select: 0 -> 115200, 1 -> 9600,2 2 -> 4800,3 2400
//    input [7:0] data, // 1 Byte Input Data
//    output reg ready, // Signal to notify tx is ready
//    output reg tx , // Serial Output
//    output reg busy
//);


endmodule
