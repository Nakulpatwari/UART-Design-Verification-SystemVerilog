`timescale 1ns/1ps

module tb;

    // ========================================================
    // Configuration
    // ========================================================

    localparam integer CLK_FREQ  = 10_000_000;
    localparam integer BAUD_RATE = 115_200;

    // ========================================================
    // Signals
    // ========================================================

    reg clk;
    reg rst;

    reg [7:0] tx_data;
    reg       tx_start;

    wire      tx;
    wire      tx_done;
    wire      tx_busy;

    wire [7:0] rx_data;
    wire       rx_done;
    wire       framing_error;

    // Loopback:
    // TX output is directly connected to RX input.
    wire rx;

    assign rx = tx;


    // ========================================================
    // DUT
    // ========================================================

    uart_top #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) dut (

        .clk           (clk),
        .rst           (rst),

        .tx_data       (tx_data),
        .tx_start      (tx_start),
        .tx            (tx),
        .tx_done       (tx_done),
        .tx_busy       (tx_busy),

        .rx            (rx),
        .rx_data       (rx_data),
        .rx_done       (rx_done),
        .framing_error (framing_error)
    );


    // ========================================================
    // Clock
    //
    // 10 MHz clock = 100 ns period
    // ========================================================

    initial begin
        clk = 1'b0;
    end

    always #50 clk = ~clk;


    // ========================================================
    // Scoreboard statistics
    // ========================================================

    integer total_tests;
    integer passed_tests;
    integer failed_tests;


    // ========================================================
    // Send one byte
    // ========================================================

    task automatic send_byte(input [7:0] data);

        begin

            // Wait until transmitter is free
            wait(tx_busy == 1'b0);

            @(posedge clk);

            tx_data  <= data;
            tx_start <= 1'b1;

            @(posedge clk);

            tx_start <= 1'b0;

            // Wait for complete RX frame
            wait(rx_done == 1'b1);

            @(posedge clk);

            total_tests = total_tests + 1;

            if (rx_data === data && framing_error == 1'b0) begin

                passed_tests = passed_tests + 1;

                $display(
                    "[PASS] TX = 0x%02h | RX = 0x%02h",
                    data,
                    rx_data
                );

            end

            else begin

                failed_tests = failed_tests + 1;

                $display(
                    "[FAIL] TX = 0x%02h | RX = 0x%02h | Frame Error = %b",
                    data,
                    rx_data,
                    framing_error
                );

            end

            // Small gap between transactions
            repeat(2) @(posedge clk);

        end

    endtask


    // ========================================================
    // Main test
    // ========================================================

    integer i;
    reg [7:0] random_data;


    initial begin

        // Initialize
        rst          = 1'b1;
        tx_data      = 8'h00;
        tx_start     = 1'b0;

        total_tests  = 0;
        passed_tests = 0;
        failed_tests = 0;


        // ----------------------------------------------------
        // Reset
        // ----------------------------------------------------

        repeat(10) @(posedge clk);

        rst = 1'b0;

        repeat(5) @(posedge clk);


        $display("");
        $display("==============================================");
        $display("       UART SYSTEMVERILOG VERIFICATION");
        $display("==============================================");
        $display("Clock Frequency : %0d Hz", CLK_FREQ);
        $display("Baud Rate       : %0d", BAUD_RATE);
        $display("==============================================");
        $display("");


        // ----------------------------------------------------
        // Directed corner cases
        // ----------------------------------------------------

        send_byte(8'h00);
        send_byte(8'hFF);
        send_byte(8'h55);
        send_byte(8'hAA);
        send_byte(8'hA5);


        // ----------------------------------------------------
        // Randomized testing
        // ----------------------------------------------------

        for (i = 0; i < 20; i = i + 1) begin

            random_data = $urandom_range(0, 255);

            send_byte(random_data);

        end


        // ----------------------------------------------------
        // Final report
        // ----------------------------------------------------

        $display("");
        $display("==============================================");
        $display("              VERIFICATION REPORT");
        $display("==============================================");
        $display("Total Tests  : %0d", total_tests);
        $display("Passed       : %0d", passed_tests);
        $display("Failed       : %0d", failed_tests);

        if (failed_tests == 0) begin
            $display("RESULT       : *** ALL TESTS PASSED ***");
        end
        else begin
            $display("RESULT       : *** VERIFICATION FAILED ***");
        end

        $display("==============================================");
        $display("");


        $finish;

    end


    // ========================================================
    // Basic assertion/check
    // ========================================================

    always @(posedge clk) begin

        if (!rst) begin

            if (framing_error === 1'bx) begin
                $display("[ASSERTION ERROR] Framing error became X");
            end

        end

    end


    // ========================================================
    // Waveform dump
    // ========================================================

    initial begin

        $dumpfile("uart_waveform.vcd");

        $dumpvars(0, tb);

    end

endmodule