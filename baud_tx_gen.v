module baud_tx_gen (
    input  wire       clk,       // system clock
    input  wire [2:0] baud_sel,  // select baud rate
    output reg        baud_tx    // pulse at normal baud rate
);

    reg [15:0] divisor;

    always @(*) begin
        case (baud_sel)
            3'b000: divisor = 16'd5208;  // 9600 baud @ 50MHz
            3'b001: divisor = 16'd2604;  // 19200
            3'b010: divisor = 16'd1302;  // 38400
            3'b011: divisor = 16'd868;   // 57600
            3'b100: divisor = 16'd434;   // 115200
            default: divisor = 16'd5208; // default 9600
        endcase
    end

    reg [15:0] counter = 0;

    always @(posedge clk) begin
        if (counter == 0) begin
            counter <= divisor - 1;
            baud_tx <= 1'b1;
        end else begin
            counter <= counter - 1;
            baud_tx <= 1'b0;
        end
    end

endmodule
