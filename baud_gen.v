module baud_gen (
    input  wire        clk,       // system clock
    input  wire [2:0]  baud_sel,  // select baud rate
    output reg         baud_tick  // pulse at baud*oversample frequency
);

    // Precomputed divisors for f_clk = 50 MHz, oversample = 16
    // baud_sel mapping:
    // 000 -> 9600
    // 001 -> 19200
    // 010 -> 38400
    // 011 -> 57600
    // 100 -> 115200
    reg [15:0] divisor;

    always @(*) begin
        case (baud_sel)
            3'b000: divisor = 16'd326;  // 9600
            3'b001: divisor = 16'd163;  // 19200
            3'b010: divisor = 16'd82;   // 38400
            3'b011: divisor = 16'd54;   // 57600
            3'b100: divisor = 16'd27;   // 115200
            default: divisor = 16'd326; // default to 9600
        endcase
    end

    reg [15:0] counter = 0;

    always @(posedge clk) begin
        if (counter == 0) begin
            counter   <= divisor - 1;
            baud_tick <= 1'b1;
        end else begin
            counter   <= counter - 1;
            baud_tick <= 1'b0;
        end
    end

endmodule
