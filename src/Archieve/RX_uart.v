`timescale 1ns / 1ps

module RX_uart(
    input clk, // 50 MHz
    input rst_n, rx, // Serial data input
    input [2:0] baud_sel, // Baud rate select: 0 -> 9600, 1 -> 19200, 2 -> 38400, 3 -> 57600, 4 -> 115200
    output reg valid,   // Data recieved is valid 
    output reg [7:0] data // 1 Byte data 
    );
    
    

    wire [15:0]baud_rx ;
    baud_rx_gen bg (
        .baud_sel(baud_sel), // Fixed to 115200 baud for now
        .baud_rx(baud_rx)
    );
    // States
    parameter   IDLE = 2'b00,
                START = 2'b01,
                DATA_BITS = 2'b10,
                STOP = 2'b11;
    
    reg [1:0] state; // state register
    reg [3:0] bit_index;    // index of bit to store
    reg [7:0] recieved_data;    // data stored in register before output 
    reg [15:0] count;    // counter for baud_rx
    
    // Comblete logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 0;
            bit_index <= 0;
            valid <= 0;
            recieved_data <= 0;
        end
        else begin
            valid <= 0; // Pulse valid for one clock only
            
            case (state)
                IDLE: begin
                    bit_index <= 0;
                    count <= 0;
                    if (rx == 0) begin
                        state <= START;
                        count <= 1'b1;
                    end
                end
                
                START: begin
                    count <= count + 1'b1;
                    
                    if (count == (baud_rx/2)) begin // Check if start bit is still valid at middle sample
                        if (rx == 1) state <= IDLE;
                    end
                    else if (count >= baud_rx - 1) begin
                        state <= DATA_BITS;
                        count <= 0;
                    end
                end
                
                DATA_BITS: begin
                    count <= count + 1;
                    
                    if (count == (baud_rx/2))
                        recieved_data[bit_index] <= rx; // Sample at middle
                    
                    if (count >= baud_rx - 1) begin
                        count <= 0;
                        if (bit_index < 7)
                            bit_index <= bit_index + 1;
                        else begin
                            state <= STOP;
                            bit_index <= 0;
                        end
                    end
                end
                
                STOP: begin
                    count <= count + 1;
                    
                    if (count == (baud_rx/2)) begin
                        if (rx == 1) begin // Valid stop bit
                            data <= recieved_data;
                            
                        end
                    end
                    
                    if (count >= baud_rx - 1) begin
                        state <= IDLE;
                        count <= 0;
                        valid <= 1;
                    end
                end
            endcase
        end
    end
endmodule
