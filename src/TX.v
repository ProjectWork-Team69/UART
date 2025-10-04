`timescale 1ns / 1ps

module TX(
    input wire          clk,
    input wire          baud_clk,
    input wire          rst_n,

    input wire          start,
    input wire          tx_en,

    input wire          fifo_en,
    input wire          fifo_empty,

    input wire [8:0]    tx_data, // can vary from 5 to 9 bits
    input wire [1:0]    parity, 
    input wire [2:0]    data_bits,
    input wire          stop_bit,

    output reg          tx,
    output reg          tx_done,
    output reg          tx_idle,
    output wire         no_data // this is to indicate no data to transmit (fifo empty and fifo_en is high

);
    // States
    parameter IDLE = 3'b000,
              START = 3'b001,
              DATA_BIT = 3'b010,
              PARITY = 3'b011,
              STOP = 3'b100;

    // registers
    reg [1:0] state, next_state; // state register
    reg [8:0] temp_frame; // stores 
    reg [3:0] no_bits;
    reg       stop_bit_copy; // copy of stop_bit
    reg [1:0] parity_copy; // copy of parity
    reg       parity_bit; // calulated parity

    assign no_data = fifo_en & fifo_empty;

    // update no. of bits, only gets updated when TX is idle 
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            no_bits <= 4'b1000;
            stop_bit_copy <= 1'b0;
            parity_copy <= 2'b00;
            parity_bit <= 1'b0;
        end else begin
            if (state == IDLE) begin
                stop_bit_copy <= stop_bit;
                parity_copy <= parity;
                case (data_bits)
                    3'b000 : no_bits <= 4'b0101;
                    3'b001 : no_bits <= 4'b0110;
                    3'b010 : no_bits <= 4'b0111;
                    3'b011 : no_bits <= 4'b1000;
                    3'b100 : no_bits <= 4'b1001;
                    default: no_bits <= 4'b1000;
                endcase
            end
            // why not in IDLE? can cause metastable state where no_bits is changing 
            if (state == DATA_BIT) begin
                // calculating parity
                case(no_bits)
                    4'd5: parity_bit <= ^tx_data[4:0];
                    4'd6: parity_bit <= ^tx_data[5:0];
                    4'd7: parity_bit <= ^tx_data[6:0];
                    4'd8: parity_bit <= ^tx_data[7:0];
                    4'd9: parity_bit <= ^tx_data[8:0];
                    default: parity_bit <= ^tx_data[7:0];
                endcase
            end
            // to cause 2 stop bits, stop_bit_copy is negated if it's found 1
            if (state == STOP) begin
                stop_bit_copy <= (stop_bit_copy) ? 1'b0 : stop_bit_copy;
            end
            else begin
                no_bits <= no_bits;
                stop_bit_copy <= stop_bit_copy;
                parity_copy <= parity_copy;
                parity_bit <= 1'b0;
            end
        end
    end

    // take a copy of input data to transmit only when idle
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            temp_frame <= 9'b0;
        else 
            temp_frame <= (cur_state == IDLE) ? tx_data : temp_frame;
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
                next_state = ((start && tx_en) || no_data) ? START : IDLE;
            START:     
                next_state = DATA_BITS;
            DATA_BITS: begin
                if (bit_index == no_bits - 1)
                    next_state = (^parity_copy) ? PARITY : STOP;
                else
                    next_state = DATA_BITS;
            end
            PARITY:
                next_state = STOP;
            STOP: begin
                // taking care of 1 or 2 stop bits
                // if stop_bit is 0 then go to stop and 
                // if stop_bit is 1 then stay for one more cycle (2 cycles in total)
                if (stop_bit_copy) begin
                    next_state = STOP;
                    stop_bit_copy = 1'b0; // reset the copy
                end else begin
                    next_state = IDLE;
                end
            end
            default:   
                next_state = IDLE;
        endcase
    end

    // Sequential logic for state behavior
    always @(posedge baud_clk or negedge rst_n) begin
        if (!rst_n) begin
            tx <= 1'b1;
            tx_done <= 0;
            tx_idle <= 1;
        end 
        else begin
            case (state)
                IDLE: begin
                   tx <= 1'b1;
                   tx_done <= 0;
                   tx_idle <= 1;
                end
                START: begin
                   tx <= 1'b0;
                   tx_done <= 0;
                   tx_idle <= 0;
                end 
                DATA_BITS: begin
                    tx <= temp_frame[0];
                    temp_frame <= {1'b0, temp_frame[8:1]}; // shift right
                    tx_done <= 0;
                    tx_idle <= 0;
                end
                PARITY: begin
                    case(parity_copy)
                        2'b01: tx <= parity_bit;      // odd parity
                        2'b10: tx <= ~parity_bit;     // even parity
                        default: tx <= 1'b0;
                    endcase
                    tx_done <= 0;
                    tx_idle <= 0;
                end
                STOP: begin
                    tx <= 1'b1;
                    tx_done <= 1;
                    tx_idle <= 0;
                end
                default : begin
                    tx <= 1'b1;
                    tx_done <= 0;
                    tx_idle <= 1;
                end
            endcase
       
        end
    end
endmodule