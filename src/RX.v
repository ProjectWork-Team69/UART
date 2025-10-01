`timescale 1ns / 1ps

// error[2] = frame error 
// error[1] = parity error 
// error[0] = overrun error
// During overrun, sacrifice the new data

// Parity 
// 00 -> None 
// 01 -> Odd 
// 10 -> Even 
// 11 -> Reserved

// Data bits 
// 000 -> 5 bits 
// 001 -> 6 bits
// 010 -> 7 bits
// 011 -> 8 bits
// 100 -> 9 bits
    
module RX(
    input wire          clk, // 50Mhz clock
    input wire          rst_n,
    input wire          rx_en,  // enables rx tranfer
    input wire [1:0]    parity, 
    input wire [2:0]    data_bits,
    input wire          stop_bit,
    input wire [15:0]   rx_divisor, // for overampling at 16 times baud clock
    input wire          rx,
    
    // Signals for over run error 
    input wire          fifo_en,
    input wire          fifo_full,
    
    output reg          rx_success, // goes high for 1 clk cycle when a byte is received
    output reg [7:0]    rx_data,
    output reg          rx_idle,
    output reg [2:0]    error 
    );
    
    // State Declaration
    // States
    parameter IDLE = 3'b000,
              START = 3'b001,
              DATA_BIT = 3'b010,
              PARITY = 3'b011,
              STOP = 3'b100;
              
    // Interal Register
    reg [2:0]   state;
    reg [3:0]   no_bits; // this reg is storing the no. of bits, only gets updateed when RX is idle 
    reg         rx_bit;
    reg [15:0]  counter;
    reg [3:0]   sample_counter;
    reg [2:0]   samples; // 3 samples to be registered in the middle at 7th, 6th and 9th sample count
    reg         rx_in; // Taking majority and using as value of RX
    reg         rx_sync1, rx_sync2, rx_d1; // Edge detector registers
    reg [3:0]   fsm_counter;
    reg [3:0]   frame_size;
    reg [3:0]   bit_counter;
    
    wire rx_negedge = rx_sync2 & ~rx_d1;
    
    // Logic for updating registers at 50Mhz 
    
    // parity error and frame error can be detected in the FSM 
    // But the overrun error requires the output being read or not 
    // there are 2 situations in this case
    // one, when FIFO_en is 0, it should check :- rx_data_valid (previous frame) AND new_frame_complete 
    // second, when FIFO_en is 1, it should check :- fifo_full AND new_frame_complete
    
    // update no. of bits anf frame size, only gets updateed when RX is idle 
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            no_bits <= 4'b1000;
            frame_size <= 4'b1010; // 8 data bits + 1 start + 1 stop
        else 
            if (cur_state == IDLE) begin
                case (data_bits)
                    3'b000 : no_bits <= 4'b0101;
                    3'b001 : no_bits <= 4'b0110;
                    3'b010 : no_bits <= 4'b0111;
                    3'b011 : no_bits <= 4'b1000;
                    3'b100 : no_bits <= 4'b1001;
                    default: no_bits <= 4'b1000;
                endcase
                frame_size <= no_bits + 4'b0001 + (^parity) + 4'b0001 + stop_bit; // Updated frame size
            end
            else begin
                no_bits <= no_bits;
                frame_size <= frame_size;
            end
    end

    // Logic to oversample input and take majority
    // generate sample counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 16'b0;
            sample_counter <= 4'b0;
        end
        else begin
            if (counter == 16'b0) begin
                counter <= (rx_divisor/16'd16) - 16'b1;
                if (sample_counter >= 4'b0)
                    sample_counter <= 4'b1111; 
                else
                    sample_counter <= sample_counter - 4'b1;
            end else begin
                counter <= counter - 16'b1;
            end
        end
    end
    
    // Frame bit counter for FSM
    // have to look at how to enable the counter only when 
    // - the rx goes low 
    // - should do (frame + 1 start bit + parity + 1 or 2 stop bit) times
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fsm_counter <= 4'b0;
        end
        else begin
            if (cur_state == IDLE && rx_negedge) 
                fsm_counter <= 4'b0;
            else if (sample_counter == 4'b0000) 
                fsm_counter <= fsm_counter + 4'b1;
            else 
                fsm_counter <= fsm_counter;
        end
    end
    
    
    // Take majority of few inputs and take majority 
    // sample data at 7th , 8th and 9th count
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            samples <= 3'b0;
        end
        else begin
            if (rx_idle) 
                samples <= 3'b0;
            else begin
                case (sample_counter)
                    4'b0111 : samples <= {samples[2:1], rx};
                    4'b1000 : samples <= {samples[2], rx, samples[0]};
                    4'b0111 : samples <= {rx, samples[1:0]};
                    default: samples <= samples;
                endcase
            end
        end
    end
    
    // take majority
    // Majority of f(A,B,C) = A.B + B.C + C.A
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_in <= 1'b1;
        end
        else begin
            rx_in <= (samples[2] && samples[1]) || (samples[1] && samples[0]) || (samples[0] && samples[2]);
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
            rx_d1    <= 1'b1;
        end
        else begin
            rx_sync1 <= rx;      // First FF for metastability
            rx_sync2 <= rx_sync1; // Second FF 
            rx_d1    <= rx_sync2; // For edge detection
        end
    end


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
                    if (rx_negedge) begin
                        state <= START;
                        count <= 1'b1;
                    end
                end
                
                START: begin
                    count <= count + 1'b1;
                    
                    if (count == (rx_divisor >> 2)) begin // Check if start bit is still valid at middle sample
                        if (rx == 1) state <= IDLE;
                    end
                    else if (count >= rx_divisor - 1) begin
                        state <= DATA_BITS;
                        count <= 0;
                    end
                    else begin
                        state <= state;
                    end 
                end
                
                DATA_BITS: begin
                    count <= count + 1;
                    
                    if (count == (rx_divisor >> 2))
                        recieved_data[bit_index] <= rx_in; // taking majority of 3 input from rx_in
                    
                    if (count >= rx_divisor - 1) begin
                        count <= 0;
                        if (bit_index < no_bits - 1)
                            bit_index <= bit_index + 1;
                        else begin
                            state <= (^parity) ? PARITY : STOP;
                            bit_index <= 0;
                        end
                    end
                end

                PARITY: begin
                    count <= count + 1;
                    
                    if (count == (rx_divisor >> 2)) begin
                        // if 01 odd parity else 10 even parity
                        if (parity == 2'b01) begin
                            if (^recieved_data == rx_in) // odd parity check
                                error[1] <= 1'b0;
                            else
                                error[1] <= 1'b1;
                        end
                        else if (parity == 2'b10) begin
                            if (~^recieved_data == rx_in) // even parity check
                                error[1] <= 1'b0;
                            else
                                error[1] <= 1'b1;
                        end
                        else begin
                            error[1] <= 1'b0;
                        end
                    end
                    
                    if (count >= rx_divisor - 1) begin
                        state <= STOP;
                        count <= 0;
                    end
                end
                
                STOP: begin
                    count <= count + 1;
                    
                    // Handling frame error and changing state to idle 
                    // if stop_bit is 1 then 2 stop bits are expected else 1 stop bit is expected
                    
                end
            endcase
        end
    end
    
endmodule
