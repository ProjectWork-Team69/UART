`timescale 1ns / 1ps

module TX(
    input wire          clk,
    input wire          baud_clk,
    input wire          rst_n,
    input wire          start,
    input wire          fifo_en,
    input wire          fifo_empty,
    input wire [8:0]    tx_data,
    input wire [1:0]    parity, 
    input wire [2:0]    data_bits,
    input wire          stop_bit,
    input wire          tx_en,

    output reg          tx,
    output reg          tx_done,
    output reg          tx_idle,

);
    // States
    parameter IDLE = 3'b000,
              START = 3'b001,
              DATA_BIT = 3'b010,
              PARITY = 3'b011,
              STOP = 3'b100;

    // registers
    reg [1:0]  state, next_state; // state register
    reg [10:0] temp_frame; // stores 
    reg [3:0]  no_bits;
    reg []

    // update no. of bits anf frame size, only gets updateed when TX is idle 
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

    // state FSM logic
    always @(posedge baud_clk or negedge rst_n) begin
        if (!rst_n) 
            state <= IDLE;
        else 
            state <= next_state;
    end

    // Combinational logic for next_state
    always @(*) begin
              case (state)
            IDLE:      
                next_state = (start && tx_en) ? START : IDLE;
            START:     
                next_state = (baud_tx) ? DATA_BITS : START;
            DATA_BITS: 
                next_state = (baud_tx && bit_index == 7) ? STOP : DATA_BITS;
            STOP:      
                next_state = (baud_tx) ? IDLE : STOP;
            default:   
                next_state = IDLE;
        endcase
    end

endmodule