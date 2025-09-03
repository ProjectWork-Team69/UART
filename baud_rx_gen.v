module baud_rx_gen (
    input  wire       clk,       // system clock
    input  wire [2:0] baud_sel,  // select baud rate
    output reg        baud_rx    // pulse at 16x oversampled baud rate
);

    reg [15:0] divisor;

    always @(*) begin
        case (baud_sel)
            3'b000: divisor = 16'd326;  // 9600 baud * 16 @ 50MHz
            3'b001: divisor = 16'd163;  // 19200
            3'b010: divisor = 16'd82;   // 38400
            3'b011: divisor = 16'd54;   // 57600
            3'b100: divisor = 16'd27;   // 115200
            default: divisor = 16'd326; // default 9600
        endcase
    end

    reg [15:0] counter = 0;

    always @(posedge clk) begin
        if (counter == 0) begin
            counter <= divisor - 1;
            baud_rx <= 1'b1;
        end else begin
            counter <= counter - 1;
            baud_rx <= 1'b0;
        end
    end

endmodule
