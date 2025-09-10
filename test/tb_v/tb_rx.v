module tb_rx();
    // Testbench signals
    reg clk;
    reg rst_n;

    // TX signals
    reg start;
    reg [2:0] tx_baud_sel;
    reg [7:0] tx_data;
    wire ready;
    wire tx_out;
    wire busy;

    // RX signals
    reg [2:0] rx_baud_sel;
    wire valid;
    wire [7:0] rx_data;

    // Clock generation (50 MHz)
    localparam CLK_PERIOD = 20; // 10ns high, 10ns low = 20ns period
    always #(CLK_PERIOD/2) clk = ~clk;

    // TX module instantiation
    TX_uart tx_uart_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .baud_sel(tx_baud_sel),
        .data(tx_data),
        .ready(ready),
        .tx(tx_out),
        .busy(busy)
    );

    // RX module instantiation
    RX_uart rx_uart_inst (
        .clk(clk),
        .rst_n(rst_n),
        .rx(tx_out),      // Connect TX output to RX input
        .baud_sel(rx_baud_sel),
        .valid(valid),
        .data(rx_data)
    );

    // Task to send data and verify reception
    task send_and_verify(input [7:0] data_to_send, input [2:0] baud_setting);
        begin
            // Set baud rate for both TX and RX
            tx_baud_sel = baud_setting;
            rx_baud_sel = baud_setting;
            tx_data     = data_to_send;

            // Wait for TX to be ready for a new transmission
            wait(ready);
            #100;

            // Start transmission with a single-cycle pulse
            $display("--> [TIME: %0t] Sending data: 0x%02h with baud_sel: %d", $time, tx_data, tx_baud_sel);
            start = 1;
            #(CLK_PERIOD);
            start = 0;

            // Wait for the TX module to finish sending all bits
            wait(!busy);
            $display("--- [TIME: %0t] TX has finished sending.", $time);

            // CRITICAL: Wait for the RX module to signal it has received valid data
            wait(valid);
            $display("--- [TIME: %0t] RX has received valid data.", $time);
            #(CLK_PERIOD); // Small delay to ensure data is stable

            // Check if received data matches transmitted data
            if (rx_data == tx_data) begin
                $display("PASS: TX sent 0x%02h, RX received 0x%02h", tx_data, rx_data);
            end else begin
                $display("FAIL: TX sent 0x%02h, RX received 0x%02h", tx_data, rx_data);
            end
            
            // Add a delay between tests for clarity
            #1000;
        end
    endtask

    // Main test sequence
    initial begin
        // 1. Initialize signals and apply reset
        $display("--- Starting Simulation ---");
        clk   = 0;
        rst_n = 0;
        start = 0;
        tx_baud_sel = 3'd0;
        rx_baud_sel = 3'd0;
        tx_data     = 8'd0;

        // Apply reset for 100ns
        #100;
        rst_n = 1;
        #100;

        // 2. Run test cases using the task
        // Test 1: Data 0xAA at 115200 baud
        send_and_verify(8'haa, 3'd4); // Assuming 3'd4 is 115200

        // Test 2: Data 0x55 at 115200 baud
        send_and_verify(8'h55, 3'd4); // Same baud rate

        // Test 3: Data 0x88 at a DIFFERENT baud rate (e.g., 9600)
        // This is the test that was failing for you.
        send_and_verify(8'hff, 3'd0); // Assuming 3'd0 is 9600

        // Test 4: Another test with a new data pattern and baud rate
        send_and_verify(8'hF0, 3'd2);

        // 3. Finish the simulation
        $display("--- Simulation Finished ---");
        #1000;
        $finish;
    end
endmodule