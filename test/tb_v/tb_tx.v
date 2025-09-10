
module tb_tx;

reg clk = 0;
reg rst_n = 0;
reg start = 0;
reg [2:0] baud_sel;  // Keep constant
reg [7:0] data = 0;
wire ready;
wire tx;
wire busy;
// DUT
TX_uart uut(
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
    baud_sel = 3'b100;
    #100 rst_n = 1;
    #100;
    
 // Send 0x55 at 9600 baud
data = 8'h55;
start = 1; #20; start = 0;
#2000000;

// Send 0xAA at 38400 baud
data = 8'haa;
baud_sel = 3'b010;
start = 1; #20; start = 0;
#2000000;

// Send 0xEF at 57600 baud
data = 8'hef;
baud_sel = 3'b011;
start = 1; #20; start = 0;
#2000000;   

    
    $display("Test complete");
    $finish;
end

initial begin
    $dumpfile("tb_tx.vcd");
    $dumpvars(0, tb_tx);
end

endmodule