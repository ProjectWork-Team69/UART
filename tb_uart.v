
module tb_uart;

reg clk = 0;
reg rst_n = 0;
reg start = 0;
reg [2:0] baud_sel = 3'b001;  // Keep constant
reg [7:0] data = 0;
wire ready;
wire tx;
wire busy;
// DUT
test_tx uut(
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .baud_sel(baud_sel),
    .data(data),
    .ready(ready),
    .tx(tx),
    .busy(busy)
    
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
    #70000
    data = 8'haa;
    start = 1;
    baud_sel = 3'b010;
    #20 start = 0;
    #70000
    data = 8'hef;
    start = 1;
    baud_sel = 3'b011;
    #20 start = 0;
        

    #100000;
    
    $display("Test complete");
    $finish;
end

endmodule