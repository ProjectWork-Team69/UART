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
    input wire          rx_data_read, // signal to indicate that the data has been read
    
    // Signals for over run error 
    input wire          fifo_en,
    input wire          fifo_full,
    
    output reg          rx_success, // goes high for 1 clk cycle when a byte is received
    output reg [8:0]    rx_data, // can be 5 - 9 bits of data
    output reg          rx_idle,
    output reg          rx_done,
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
    // Baud rate clock divider - counts down from (rx_divisor/16)-1 to 0
    // Generates 16 sample points per UART bit period for oversampling
    reg [15:0]  counter; 
    reg [3:0]   sample_counter; // Tracks position within 16-sample oversampling window
    reg [2:0]   samples; // 3 samples to be registered in the middle at 7th, 6th and 9th sample count
    reg         rx_in; // Taking majority and using as value of RX
    reg         rx_sync1, rx_sync2, rx_d1; // Edge detector registers
    reg [3:0]   frame_counter;    // countes the frame bits
    reg [3:0]   frame_size;
    reg [10:0]  temp_frame; // temp frame to store start, data, parity and no stop bits
    reg         parity_error;
    
    wire rx_negedge = rx_sync2 & ~rx_d1;
    wire calc_even_parity;
    wire calc_odd_parity;
    
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
                counter <= (rx_divisor >> 4) - 16'b1;
                if (sample_counter >= 4'b1111)
                    sample_counter <= 4'b0; 
                else
                    sample_counter <= sample_counter + 4'b1;
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
            frame_counter <= 4'b0;
        end
        else begin
            if (cur_state == IDLE && rx_negedge) 
                frame_counter <= 4'b0;
            else if (sample_counter == 4'b0000) 
                frame_counter <= frame_counter + 4'b1;
            else 
                frame_counter <= frame_counter;
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
            rx_done <= 1'b0;
            rx_success <= 1'b0;
            temp_frame <= 12'b0;
            error <= 3'b0;
            rx_idle <= 1'b1;
        end
        else begin
            case (state)
                IDLE: begin
                    if (rx_negedge) begin
                        state <= START;
                        rx_idle <= 1'b0;
                    end
                    else begin
                        state <= IDLE;
                        rx_idle <= 1'b1;
                    end
                    rx_done <= 1'b0;
                    rx_success <= 1'b0;
                    temp_frame <= 12'b0;
                    error <= 3'b0;

                end
                
                START: begin
                    if (sample_counter == 4'b1000) begin // Check if start bit is still valid at middle sample
                        if (rx == 1) state <= IDLE;
                    end
                    else if (sample_counter >= 4'b1111) begin
                        state <= DATA_BITS;
                    end
                    temp_frame[0] <= rx_in; // Store start bit
                end
                
                DATA_BITS: begin
                    if (frame_counter <= no_bits) begin
                        temp_frame[frame_counter] <= rx_in; // Store data bits
                    end
                    if (frame_counter == no_bits && sample_counter == 4'b1111) begin
                        state <= (^parity) ? PARITY : STOP; // Move to PARITY or STOP based on config
                    end
                end

                PARITY: begin
                    temp_frame[frame_counter] <= rx_in; // Store parity bit
                    state <= (sample_counter == 4'b1111) ? STOP : PARITY; // Move to STOP after parity bit
                end
                
                STOP: begin
                    if (frame_counter == (frame_size - 4'b1) && sample_counter == 4'b1111) begin
                        state <= IDLE;
                        rx_done <= 1'b1;
                        rx_success <= ~parity_error; // Pulse for one clk cycle
                        
                        // Overrun error check
                        if (fifo_en) begin
                            error[0] <= fifo_full; // Overrun error
                        end
                        else begin
                            error[0] <= (rx_data_read) ? 1'b0 : 1'b1; // Overrun error
                        end
                    end
                    else
                        state <= STOP;

                    // Frame error check
                    if (rx_in != 1'b1) 
                        error[2] <= 1'b1; // Frame error
                    else 
                        error[2] <= 1'b0;
                end
                default: begin
                    state <= IDLE;
                    rx_done <= 1'b0;
                    rx_success <= 1'b0;
                    temp_frame <= 12'b0;
                    error <= 3'b0;
                    rx_idle <= 1'b1;
                end
            endcase
        end
    end

    // Parity calculation for both modes
    calc_even_parity = ^temp_frame[no_bits:1];  // Even: XOR of all bits
    calc_odd_parity = ~calc_even_parity;   // Odd: NOT of even parity

    // Check parity based on configuration
    always @(*) begin
        case (parity_mode)
            2'b00: parity_error = 1'b0;                              // No parity
            2'b01: parity_error = (temp_frame[no_bits + 4'b1] != calc_odd_parity); // Odd parity
            2'b10: parity_error = (temp_frame[no_bits + 4'b1] != calc_even_parity);// Even parity
            default: parity_error = 1'b0;
        endcase
        // take only the required bits from temp_frame
        // temp_frame[0] = start bit
        // temp_frame[no_bits:1] = data bits
        rx_data = temp_frame[no_bits:1];
    end
    
endmodule
