`timescale 1ns / 1ps

module test_rx(
    input clk, // 50 MHz
    input rst_n, rx, // Serial data input
    output reg valid,   // Data recieved is valid 
    output reg [7:0] data // 1 Byte data 
    );
    
    // Constants 
    parameter CPB = 'd434; // Clk per bits (CPB) = clk cycle / baud rate ==> 50Mhz / 115200
    
    // States
    parameter   IDLE = 2'b00,
                START = 2'b01,
                DATA_BITS = 2'b11,
                STOP = 2'b10;
    
    reg [1:0] state; // state register
    reg [3:0] bit_index;    // index of bit to store
    reg [7:0] recieved_data;    // data stored in register before output 
    reg [8:0] count;    // counter for CPB
    
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
                    
                    if (count == (CPB/2)) begin // Check if start bit is still valid at middle sample
                        if (rx == 1) state <= IDLE;
                    end
                    else if (count >= CPB - 1) begin
                        state <= DATA_BITS;
                        count <= 0;
                    end
                end
                
                DATA_BITS: begin
                    count <= count + 1;
                    
                    if (count == (CPB/2))
                        recieved_data[bit_index] <= rx; // Sample at middle
                    
                    if (count >= CPB - 1) begin
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
                    
                    if (count == (CPB/2)) begin
                        if (rx == 1) begin // Valid stop bit
                            data <= recieved_data;
                            valid <= 1;
                        end
                    end
                    
                    if (count >= CPB - 1) begin
                        state <= IDLE;
                        count <= 0;
                    end
                end
            endcase
        end
    end
endmodule
