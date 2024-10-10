/*
 * Copyright (C) 2024 ETH Zurich
 * All rights reserved.
 *
 * This software may be modified and distributed under the terms
 * of the GPL-3.0 license.  See the LICENSE file for details.
 */
 
 `timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//
// proprietary S-Bus UART interface
// 
// protocol: 100 kBit/sec baudrate, inverted logic
//           8 data bits, 1 parity bit (even), 2 stop bits
//
// see also: https://digitalwire.ch/de/projekte/futaba-sbus/
//
//////////////////////////////////////////////////////////////////////////////////


module sbus_uart #(
    parameter SAMPLE_TICKS = 1000,
    parameter IDLE_TIME_TICKS = 300000) (
    input clk_i,
    input rst_ni,
    input sbus_i,
    output [7:0] data_o,
    output rdy_o,
    output err_o
    );

    // input syncronization
    reg sbus_meta, sbus_sync, sbus_sync_prev;

    // internal registers
    reg [31:0] clk_cnt, clk_cnt_next;
    reg [31:0] idle_timer, idle_timer_next;
    reg rdy, rdy_next;
    reg err, err_next;
    reg [3:0] parity, parity_next;
    reg [3:0] bit_cnt, bit_cnt_next;
    reg [7:0] sbus_shift, sbus_shift_next;
    reg [7:0] data, data_next;    

    // FSM
    localparam
        SYNC    = 3'b000,
        WAIT    = 3'b001,
        START   = 3'b010,
        SAMPLE  = 3'b011,
        ERROR   = 3'b100;
    reg [2:0] state, state_next;

    // sampling
    localparam HALF_SAMPLE_TICKS = SAMPLE_TICKS / 2;

    // input synchronization
    always @ (posedge clk_i, negedge rst_ni) begin
        if (rst_ni == 'b0) begin
            sbus_meta <= 1'b0;
            sbus_sync <= 1'b0;
            sbus_sync_prev <= 1'b0;
        end else begin
            sbus_meta <= sbus_i;
            sbus_sync <= sbus_meta;
            sbus_sync_prev <= sbus_sync;
        end
    end

    // internal registers
    always @ (posedge clk_i, negedge rst_ni) begin
        if (rst_ni == 'b0) begin
            clk_cnt <= 1;
            idle_timer <= 0;
            rdy <= 1'b0;
            err <= 1'b0;
            parity <= 0;
            bit_cnt <= 0;
            sbus_shift <= 8'h00;
            data <= 8'h00;
        end else begin
            clk_cnt <= clk_cnt_next;
            idle_timer <= idle_timer_next;
            rdy <= rdy_next;
            err <= err_next;
            parity <= parity_next;
            bit_cnt <= bit_cnt_next;
            sbus_shift <= sbus_shift_next;
            data <= data_next;
        end
    end

    // assign next state
    always @ (posedge clk_i, negedge rst_ni) begin
        if (rst_ni == 'b0) begin
            state <= SYNC;
        end else begin
            state <= state_next;
        end
    end

    // next state logic
    always @(*) begin
        // defaults
        state_next = state;
        clk_cnt_next = clk_cnt;
        idle_timer_next = idle_timer;
        rdy_next = rdy;
        err_next = err;
        parity_next = parity;
        bit_cnt_next = bit_cnt;
        sbus_shift_next = sbus_shift;
        data_next = data;
        
        // make sure ready signal is asserted for one clock cycle only
        if (rdy == 1) begin
            rdy_next = 1'b0;
        end

        case (state)
            SYNC: begin
                // check if sbus line is low for some pre-defined time,
                // to be sure to capture the start bit of the first uart frame
                if (sbus_sync == 1'b0) begin
                    idle_timer_next = idle_timer + 1;
                end else begin
                    idle_timer_next = 0;
                end
                if (idle_timer > IDLE_TIME_TICKS) begin
                    state_next = WAIT;
                    idle_timer_next = 0;                    
                end
            end
            WAIT: begin
                // wait for assertion of start bit
                if ((sbus_sync_prev == 1'b0) && (sbus_sync == 1'b1)) begin
                    clk_cnt_next = 1;
                    state_next = START;
                end
            end
            START: begin
                clk_cnt_next = clk_cnt + 1;

                // start sampling at 50% of bit period
                if (clk_cnt >= HALF_SAMPLE_TICKS) begin
                    clk_cnt_next = 1;
                    bit_cnt_next = 0;
                    parity_next = 0;
                    state_next = SAMPLE;
                end
            end
            SAMPLE: begin
                clk_cnt_next = clk_cnt + 1;

                // sample at 100kBit rate
                if (clk_cnt >= SAMPLE_TICKS) begin
                    clk_cnt_next = 1;
                    sbus_shift_next[7:1] = sbus_shift[6:0];
                    sbus_shift_next[0] = sbus_sync;

                    bit_cnt_next = bit_cnt + 1;
                    if (bit_cnt < 8) begin
                        if (sbus_sync == 1'b0) begin
                            parity_next = parity + 1;
                        end
                    end else if (bit_cnt == 8) begin
                        data_next = ~sbus_shift;
                        // check parity bit
                        if ((~sbus_sync + parity) % 2) begin
                            state_next = ERROR;
                        end
                    end else if (bit_cnt == 9) begin
                        // check stop bit 1
                        if (sbus_sync == 1'b1) begin
                            state_next = ERROR;
                        end
                    end else if (bit_cnt == 10) begin
                        // check stop bit 2
                        if (sbus_sync == 1'b1) begin
                            state_next = ERROR;
                        end
                        else begin
                            // data valid and ready
                            rdy_next = 1'b1;
                            state_next = WAIT;
                        end
                    end else begin
                        // should never reach this
                        state_next = ERROR;
                    end
                end
            end
            ERROR: begin
                err_next = 1'b1;
            end
            default:
                // should never reach this
                err_next = 1'b1;
        endcase
    end

    assign data_o = data;
    assign rdy_o = rdy;
    assign err_o = err;
endmodule
