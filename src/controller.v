`timescale 1ns / 1ps

module controller(
    input wire      clk,
    input wire      rst_n,
    input wire      fifo_en,
    // RX interface 
        // inputs
        input wire  [8:0]   rx_data,
        input wire  [2:0]   rx_error,
        input wire          rx_valid,
        input wire          rx_done,

        // outputs
        output reg          rx_ready,
        output reg          rx_fifo_empty,
        output reg          rx_fifo_full,
    // TX interface
        // inputs
        input wire          tx_ready,
        input wire          start,
        input wire          tx_idle,

        // outputs
        output reg          tx_start,
        output reg  [8:0]   tx_data,
        output reg          tx_valid,
        output reg          tx_fifo_empty,
        output reg          tx_fifo_full,

    // AXI interface
        // inputs
        // RX AXI side
        input wire          rx_ready_axi,

        // outputs
        // RX AXI side
        output reg          rx_valid_axi,
        output reg  [31:0]   rx_data_axi,

        // TX AXI side
        input wire          tx_valid_axi,
        input wire  [31:0]  tx_data_axi,

        output reg          tx_ready_axi
);

    // registers
    reg rx_fifo_wr_en, rx_fifo_rd_en;
    reg [15:0] rx_fifo_wr_data, rx_fifo_rd_data;
    reg tx_fifo_wr_en, tx_fifo_rd_en;
    reg [15:0] tx_fifo_wr_data, tx_fifo_rd_data;
    // wires

    // FIFO instantiation
    // RX FIFO
    sync_fifo #(
        .DATA_WIDTH(16),
        .DEPTH(16)
    ) rx_fifo (
        .clk(clk),
        .reset_n(rst_n),
        .wr_en(rx_fifo_wr_en),
        .rd_en(rx_fifo_rd_en),
        .wr_data(rx_fifo_wr_data),
        .rd_data(rx_fifo_rd_data),
        .full(rx_fifo_full),
        .empty(rx_fifo_empty)
    );

    // TX FIFO
    sync_fifo #(
        .DATA_WIDTH(16),
        .DEPTH(16)
    ) tx_fifo (
        .clk(clk),
        .reset_n(rst_n),
        .wr_en(tx_fifo_wr_en),
        .rd_en(tx_fifo_rd_en),
        .wr_data(tx_fifo_wr_data),
        .rd_data(tx_fifo_rd_data),
        .full(tx_fifo_full),
        .empty(tx_fifo_empty)
    );

    always @(*) begin
        if (fifo_en) begin
            // If fifo is enabled, handle RX interface through FIFO
            rx_ready = !rx_fifo_full;
            rx_valid_axi = !rx_fifo_empty;
            rx_data_axi = {16'b0,rx_fifo_rd_data};
            rx_fifo_wr_data = {4'b0, rx_error, rx_data};
        end else begin
            // direct connection when FIFO is not enabled
            rx_ready = rx_ready_axi;
            rx_valid_axi = rx_valid;
            rx_data_axi = {20'b0, rx_error, rx_data};
            rx_fifo_wr_data = 16'b0;
        end
    end

    // Controlling wr_en and rd_en of RX fifo only if fifo_en
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_fifo_rd_en <= 1'b0;
            rx_fifo_wr_en <= 1'b0;
        end
        else if (fifo_en) begin
            // Controller as Reciever and RX module as sender - conditinon to enable wr_en of fifo
            rx_fifo_wr_en <= rx_valid & rx_ready & rx_done;
            // Controller as sender and RX module as sender - condition to enable rd_en of fifo
            rx_fifo_rd_en <= rx_ready_axi & rx_valid_axi;
        end 
        else begin
            rx_fifo_rd_en <= 1'b0;
            rx_fifo_wr_en <= 1'b0;
        end
    end

    // TX FIFO control signals
    always @(*) begin
        if (fifo_en) begin
            // If fifo is enabled, handle TX interface through FIFO
            tx_ready_axi = !tx_fifo_empty;
            tx_data = tx_fifo_rd_data[8:0];
            tx_valid = !tx_fifo_full;
            tx_fifo_wr_data = tx_data_axi[15:0];
            tx_start = !tx_fifo_empty & tx_idle;
        end else begin
            // direct connection when FIFO is not enabled
            tx_ready_axi = tx_ready;
            tx_start = start & tx_idle;
            tx_data = tx_data_axi[8:0];
            tx_valid = tx_valid_axi & tx_ready;
            tx_fifo_wr_data = 16'b0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_fifo_rd_en <= 1'b0;
            tx_fifo_wr_en <= 1'b0;
        end
        else if (fifo_en) begin
            // Controller as sender and TX module as reciever - condition to enable rd_en of fifo
            tx_fifo_rd_en <= tx_ready & !tx_fifo_empty & tx_idle;
            // AXI as sender and Controller as reciever - condition to enable wr_en of fifo
            tx_fifo_wr_en <= tx_valid_axi & tx_ready_axi;
        end 
        else begin
            tx_fifo_rd_en <= 1'b0;
            tx_fifo_wr_en <= 1'b0;
        end
    end

endmodule
