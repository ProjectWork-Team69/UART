`timescale 1ns / 1ps

module controller(
    // RX interface 
        // inputs

        // outputs

    // TX interface
        // inputs

        // outputs

    // AXI interface
        // inputs

        // outputs

);

    // registers

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

    

endmodule