`timescale 1ns / 1ps

module baud_clk_gen(
    input wire          clk, 
    input wire          rst_n,
    input wire [15:0]   baud_divisor,
    
    // check if the RX and TX are idle
    // there will be a signal from TX and RX when it is in idle state
    input wire          rx_idle,
    input wire          tx_idle,
    
    output reg          baud_clk_tx,
    output reg          baud_clk_rx,
    output wire [15:0]  rx_baud_divisor,
    output wire [15:0]  tx_baud_divisor
    
    // I need handshake signals here valid and ready
    // Not sure
    );
    
    // internal divisior reg for RX to update when rx is ready or in idle state
    reg [15:0]  rx_divisor;
    // internal divisor reg for TX to update when tx is ready or in idle state 
    reg [15:0]  tx_divisor;
    // This is done to prevent the baud clock to update when the transaction is in process
    
    reg [15:0]  rx_counter;
    reg [15:0]  tx_counter;
    
    // Double synchronising FF for rx_idle and tx_idle signal
    reg rx_is_idle, tx_is_idle;
    
    reg [1:0] rx_sync_ff, tx_sync_ff;
    
    reg tx_divisor_changed, rx_divisor_changed;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync_ff <= 2'b0;
            tx_sync_ff <= 2'b0;
        end
        else begin
            rx_sync_ff <= {rx_sync_ff[0], rx_idle};
            tx_sync_ff <= {tx_sync_ff[0], tx_idle};
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_is_idle <= 1'b0;
            tx_is_idle <= 1'b0;
        end
        else begin
            rx_is_idle <= rx_sync_ff[0] & ~rx_sync_ff[1];
            tx_is_idle <= tx_sync_ff[0] & ~tx_sync_ff[1];
        end
     end
     
     
    // Update of internal reg with input baud_divisor
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_divisor <= 16'd5208; // Default to 9600 baud
            tx_divisor <= 16'd5208; // Default to 9600 baud
        end
        else begin
            rx_divisor <= (rx_is_idle) ? baud_divisor : rx_divisor;
            tx_divisor <= (tx_is_idle) ? baud_divisor : tx_divisor;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_divisor_changed <= 1'b0;
            rx_divisor_changed <= 1'b0;
        end
        else begin
            // Generate single-cycle pulse when divisor updates
            tx_divisor_changed <= tx_idle && (tx_divisor != baud_divisor);
            rx_divisor_changed <= rx_idle && (rx_divisor != baud_divisor);
        end
    end
    
    // generation of clock
    
    // RX baud clock
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_counter <= 16'b0;
            baud_clk_rx <= 1'b0;
        end
        else begin
            if (rx_counter == 16'b0 || rx_divisor_changed) begin
                rx_counter <= (rx_divisor >> 1) - 16'b1;
                baud_clk_rx <= ~baud_clk_rx;  // toggle 
            end else begin
                rx_counter <= rx_counter - 16'b1;
            end
        end
    end
    
    // TX baud clock
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_counter <= 16'b0;
            baud_clk_tx <= 1'b0;
        end
        else begin
            if (tx_counter == 16'b0 || tx_divisor_changed) begin
                tx_counter <= (tx_divisor >> 1) - 16'b1;
                baud_clk_tx <= ~baud_clk_tx;  // toggle 
            end else begin
                tx_counter <= tx_counter - 16'b1;
            end
        end
    end
    
    assign rx_baud_divisor = rx_divisor;
    assign tx_baud_divisor = tx_divisor;
    
endmodule
