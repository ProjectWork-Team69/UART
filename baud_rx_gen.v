module baud_rx_gen (
    input  wire [2:0] baud_sel,  // select baud rate
    output reg  [15:0]     baud_rx    // pulse at 16x oversampled baud rate
);


    always @(*) begin
        case (baud_sel)
            3'b000: baud_rx = 16'd5208;  // 9600 baud * 16 @ 50MHz
            3'b001: baud_rx = 16'd2604;  // 19200
            3'b010: baud_rx = 16'd1302;   // 38400
            3'b011: baud_rx = 16'd868;   // 57600
            3'b100: baud_rx = 16'd434;   // 115200
            default: baud_rx = 16'd5208; // default 9600
        endcase
    end


endmodule
