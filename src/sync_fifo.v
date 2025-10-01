`timescale 1ns / 1ps

module sync_fifo #(
    parameter DATA_WIDTH=16,
    parameter DEPTH=16
    )
    (
    input   wire    clk, reset_n,
    input   wire    wr_en, rd_en,
    input   wire    [DATA_WIDTH-1:0] wr_data, 
    output  reg     [DATA_WIDTH-1:0] rd_data,
    output  wire    full, empty
);

reg [DATA_WIDTH-1:0] array [0:DEPTH-1];
reg [$clog2(DEPTH):0] wr_ptr,rd_ptr;

// write logic 
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        wr_ptr <= 'd0;
    end
    else if (wr_en && !full) begin
        array[wr_ptr[$clog2(DEPTH)-1:0]] <= wr_data;
        wr_ptr <= wr_ptr + 1'b1;
    end
end

// read logic 
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        rd_ptr <= 'd0;
        rd_data <= 'd0;
    end
    else if (rd_en && !empty) begin
        rd_data <= array[rd_ptr[$clog2(DEPTH)-1:0]];
        rd_ptr <= rd_ptr + 1;
    end
    else begin
        rd_data <= rd_data;
    end
end

// Full and empty logic 
assign full = (wr_ptr - rd_ptr == DEPTH);
assign empty = (wr_ptr == rd_ptr);

endmodule
