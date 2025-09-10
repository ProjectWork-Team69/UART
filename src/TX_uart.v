

module TX_uart (
    input clk, // 50 MHz
    input rst_n,
    input start, // Initiate tx
    input [2:0] baud_sel, // Baud rate select: 0 -> 115200, 1 -> 9600,2 2 -> 4800,3 2400
    input [7:0] data, // 1 Byte Input Data
    output reg ready, // Signal to notify tx is ready
    output reg tx,  // Serial Output
    output reg busy
);


wire baud_tx ;
baud_tx_gen bg (
        .clk(clk),
        .baud_sel(baud_sel),
        .baud_tx(baud_tx)
    );

    // States
parameter IDLE = 2'b00,
                START = 2'b01,
                DATA_BITS = 2'b11,
                STOP = 2'b10;
    
    reg [1:0] state, next_state; // state register
    reg [3:0] bit_index;    // index of bit to send
    reg [7:0] transmit_data;    // data stored in register before transmit
    reg [8:0] count;    // counter for CPB
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            state <= IDLE;
        else 
            state <= next_state;
    end
    
    // Combinational logic for next_state
    always @(*) begin
              case (state)
            IDLE:      
                next_state = (start) ? START : IDLE;
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


    // Sequential logic for state behavior
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx <= 1'b1;
            ready <= 1'b1;
            bit_index <= 0;
            count <= 0;
            busy<=0;
        end 
        else begin
            case (state)
                IDLE: begin
                    tx <= 1'b1;
                    ready <= 1'b1;
                    bit_index <= 0;
                    count <= 0;
                    transmit_data <= 0;
                    busy<=0;
                end
                START: begin
                    tx <= 0;
                    ready <= 0;
                    busy<=1;

                    transmit_data <= data;
                end 
                DATA_BITS: begin
                    tx <= transmit_data[bit_index];

                if(baud_tx) begin
                        bit_index <= bit_index + 1;
                    end 

                end
                STOP: begin
                    tx <= 1'b1;
                    busy<=0;

                end
                default : begin
                    tx <= 1'b1;
                    ready <= 1'b1;
                end
            endcase
       
        end
    end
endmodule