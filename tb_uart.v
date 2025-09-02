`timescale 1ns/1ps


module tb_uart;

reg clk = 0;
reg rst_n = 0;
reg start = 0;
reg [2:0] baud_sel = 3'b00;  // Keep constant
reg [7:0] data = 0;
wire ready;
wire tx;

// DUT
test_tx uut(
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .baud_sel(baud_sel),
    .data(data),
    .ready(ready),
    .tx(tx)
);

// Clock - 50MHz
always #10 clk = ~clk;

initial begin
    // Reset
    #100 rst_n = 1;
    #100;
    
    // Send 0x55
    data = 8'h55;
    start = 1;
    #20 start = 0;
    
    // Wait for ready
    while(!ready) #20;
    #1000;
    
    // Send 0xAA  
    data = 8'hAA;
    start = 1;
    #20 start = 0;
    
    // Wait for ready
    while(!ready) #20;
    #1000;
    
    // Send 0xFF
    data = 8'hFF;
    start = 1;
    #20 start = 0;
    
    // Wait for ready
    while(!ready) #20;
    #1000;
    
    $display("Test complete");
    $finish;
end

endmodule