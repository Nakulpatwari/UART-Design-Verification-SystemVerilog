`timescale 1ns/1ps

// ============================================================
// UART TOP
// ============================================================
module uart_top #(
    parameter integer CLK_FREQ  = 10_000_000,
    parameter integer BAUD_RATE = 115_200
)(
    input  wire       clk,
    input  wire       rst,

    // Transmit interface
    input  wire [7:0] tx_data,
    input  wire       tx_start,
    output wire       tx,
    output wire       tx_done,
    output wire       tx_busy,

    // Receive interface
    input  wire       rx,
    output wire [7:0] rx_data,
    output wire       rx_done,
    output wire       framing_error
);

    uart_tx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) tx_inst (
        .clk      (clk),
        .rst      (rst),
        .data_in  (tx_data),
        .start    (tx_start),
        .tx       (tx),
        .done     (tx_done),
        .busy     (tx_busy)
    );

    uart_rx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) rx_inst (
        .clk           (clk),
        .rst           (rst),
        .rx            (rx),
        .data_out      (rx_data),
        .done          (rx_done),
        .framing_error (framing_error)
    );

endmodule


// ============================================================
// UART TRANSMITTER
//
// Frame:
//   1 start bit
//   8 data bits, LSB first
//   1 stop bit
// ============================================================
module uart_tx #(
    parameter integer CLK_FREQ  = 10_000_000,
    parameter integer BAUD_RATE = 115_200
)(
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] data_in,
    input  wire       start,

    output reg        tx,
    output reg        done,
    output reg        busy
);

    localparam integer CLKS_PER_BIT =
        CLK_FREQ / BAUD_RATE;

    localparam integer COUNT_WIDTH =
        (CLKS_PER_BIT <= 2) ? 1 : $clog2(CLKS_PER_BIT);

    localparam [1:0]
        TX_IDLE  = 2'd0,
        TX_START = 2'd1,
        TX_DATA  = 2'd2,
        TX_STOP  = 2'd3;

    reg [1:0] state;
    reg [COUNT_WIDTH-1:0] clk_count;
    reg [2:0] bit_index;
    reg [7:0] data_reg;

    always @(posedge clk) begin

        if (rst) begin
            state     <= TX_IDLE;
            clk_count <= 0;
            bit_index <= 0;
            data_reg  <= 0;
            tx        <= 1'b1;
            done      <= 1'b0;
            busy      <= 1'b0;
        end

        else begin

            // done is a one-clock pulse
            done <= 1'b0;

            case (state)

                TX_IDLE: begin

                    tx        <= 1'b1;
                    busy      <= 1'b0;
                    clk_count <= 0;
                    bit_index <= 0;

                    if (start) begin
                        data_reg  <= data_in;
                        tx        <= 1'b0;
                        busy      <= 1'b1;
                        state     <= TX_START;
                        clk_count <= 0;
                    end
                end


                TX_START: begin

                    busy <= 1'b1;

                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count <= 0;
                        bit_index <= 0;

                        tx    <= data_reg[0];
                        state <= TX_DATA;
                    end
                    else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end


                TX_DATA: begin

                    busy <= 1'b1;

                    if (clk_count == CLKS_PER_BIT - 1) begin

                        clk_count <= 0;

                        if (bit_index == 3'd7) begin
                            tx    <= 1'b1;
                            state <= TX_STOP;
                        end

                        else begin
                            bit_index <= bit_index + 1'b1;
                            tx <= data_reg[bit_index + 1'b1];
                        end
                    end

                    else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end


                TX_STOP: begin

                    busy <= 1'b1;

                    if (clk_count == CLKS_PER_BIT - 1) begin

                        clk_count <= 0;
                        tx        <= 1'b1;
                        busy      <= 1'b0;
                        done      <= 1'b1;
                        state     <= TX_IDLE;

                    end

                    else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end


                default: begin
                    state <= TX_IDLE;
                    tx    <= 1'b1;
                    busy  <= 1'b0;
                end

            endcase
        end
    end

endmodule


// ============================================================
// UART RECEIVER
//
// Detects start bit, samples near center of each bit,
// receives 8 data bits and validates stop bit.
// ============================================================
module uart_rx #(
    parameter integer CLK_FREQ  = 10_000_000,
    parameter integer BAUD_RATE = 115_200
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       rx,

    output reg [7:0]  data_out,
    output reg        done,
    output reg        framing_error
);

    localparam integer CLKS_PER_BIT =
        CLK_FREQ / BAUD_RATE;

    localparam integer HALF_BIT =
        CLKS_PER_BIT / 2;

    localparam integer COUNT_WIDTH =
        (CLKS_PER_BIT <= 2) ? 1 : $clog2(CLKS_PER_BIT);

    localparam [1:0]
        RX_IDLE  = 2'd0,
        RX_START = 2'd1,
        RX_DATA  = 2'd2,
        RX_STOP  = 2'd3;

    reg [1:0] state;

    reg [COUNT_WIDTH-1:0] clk_count;

    reg [2:0] bit_index;

    reg [7:0] data_reg;


    always @(posedge clk) begin

        if (rst) begin

            state         <= RX_IDLE;
            clk_count     <= 0;
            bit_index     <= 0;
            data_reg      <= 0;
            data_out      <= 0;
            done          <= 1'b0;
            framing_error <= 1'b0;

        end

        else begin

            // one-clock pulse
            done <= 1'b0;

            case (state)

                // ------------------------------------------------
                // Wait for falling edge / start bit
                // ------------------------------------------------
                RX_IDLE: begin

                    clk_count     <= 0;
                    bit_index     <= 0;
                    framing_error <= 1'b0;

                    if (rx == 1'b0) begin
                        state     <= RX_START;
                        clk_count <= 0;
                    end
                end


                // ------------------------------------------------
                // Validate start bit at its midpoint
                // ------------------------------------------------
                RX_START: begin

                    if (clk_count == HALF_BIT - 1) begin

                        clk_count <= 0;

                        if (rx == 1'b0) begin
                            bit_index <= 0;
                            state     <= RX_DATA;
                        end

                        else begin
                            state <= RX_IDLE;
                        end
                    end

                    else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end


                // ------------------------------------------------
                // Receive 8 data bits
                // ------------------------------------------------
                RX_DATA: begin

                    if (clk_count == CLKS_PER_BIT - 1) begin

                        clk_count <= 0;

                        data_reg[bit_index] <= rx;

                        if (bit_index == 3'd7) begin
                            state <= RX_STOP;
                        end

                        else begin
                            bit_index <= bit_index + 1'b1;
                        end
                    end

                    else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end


                // ------------------------------------------------
                // Validate stop bit
                // ------------------------------------------------
                RX_STOP: begin

                    if (clk_count == CLKS_PER_BIT - 1) begin

                        clk_count <= 0;

                        if (rx == 1'b1) begin

                            data_out <= data_reg;
                            done     <= 1'b1;

                        end

                        else begin

                            framing_error <= 1'b1;

                        end

                        state <= RX_IDLE;
                    end

                    else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end


                default: begin
                    state <= RX_IDLE;
                end

            endcase
        end
    end

endmodule