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
// proprietary S-Bus decoder
// 
// protocol: S-Bus frame consists of 25 bytes. Start byte 0xF0, 22 data bytes, flags
//           byte and end byte 0x00. The 22 data bytes represent 16 channels, i.e.
//           each channel uses 11 bit.
//
// see also: https://digitalwire.ch/de/projekte/futaba-sbus/
//
//////////////////////////////////////////////////////////////////////////////////


module sbus_decoder #(
    parameter FRAME_TIMEOUT_TICKS = 10000000) (
    input clk_i,
    input rst_ni,
    input [7:0] uart_i,
    input rdy_i,
    input err_i,
    output [10:0] channel_1_o,
    output [10:0] channel_2_o,
    output [10:0] channel_3_o,
    output [10:0] channel_4_o,
    output [10:0] channel_5_o,
    output [10:0] channel_6_o,
    output [10:0] channel_7_o,
    output [10:0] channel_8_o,
    output [10:0] channel_9_o,
    output [10:0] channel_10_o,
    output [10:0] channel_11_o,
    output [10:0] channel_12_o,
    output [10:0] channel_13_o,
    output [10:0] channel_14_o,
    output [10:0] channel_15_o,
    output [10:0] channel_16_o,
    output [7:0] flags_o,
    output frame_err_o,
    output frame_rdy_o,
    output frame_timeout_o
    );

    // S-Bus protocol
    localparam START_BYTE = 8'hF0;
    localparam END_BYTE = 8'h00;

    // internal registers
    reg [5:0] byte_cnt, byte_cnt_next;
    reg [10:0] channel [0:15], channel_next [0:15];
    reg [10:0] channel_rev [0:15], channel_rev_next [0:15];
    reg [7:0] flags, flags_next;
    reg frame_rdy, frame_rdy_next;
    reg frame_err, frame_err_next;
    reg frame_timeout, frame_timeout_next;
    reg [31:0] frame_timer, frame_timer_next;

    integer i, j;

    // FSM
    localparam
        IDLE    = 2'b00,
        DATA    = 2'b01,
        ERROR   = 2'b10,
        TIMEOUT = 2'b11;
    reg [1:0] state, state_next;

    // internal registers
    always @ (posedge clk_i, negedge rst_ni) begin
        if (rst_ni == 'b0) begin
            for (i=0; i<16; i=i+1) begin
                channel[i] <= 0;
            end
            for (i=0; i<16; i=i+1) begin
                channel_rev[i] <= 0;
            end
            byte_cnt <= 0;
            flags <= 0;
            frame_rdy <= 1'b0;
            frame_err <= 1'b0;
            frame_timeout <= 1'b0;
        end else begin
            for (i=0; i<16; i=i+1) begin
                channel[i] <= channel_next[i];
            end
            for (i=0; i<16; i=i+1) begin
                channel_rev[i] <= channel_rev_next[i];
            end
            byte_cnt <= byte_cnt_next;
            flags <= flags_next;
            frame_rdy <= frame_rdy_next;
            frame_err <= frame_err_next;
            frame_timeout <= frame_timeout_next;
        end
    end

    // timer
    always @ (posedge clk_i, negedge rst_ni) begin
        if (rst_ni == 'b0) begin
            frame_timer <= 0;
        end else begin
            frame_timer <= frame_timer_next;
        end
    end

    // assign next state
    always @ (posedge clk_i, negedge rst_ni) begin
        if (rst_ni == 'b0) begin
            state <= IDLE;
        end else begin
            state <= state_next;
        end
    end

    // next state logic
    always @(*) begin
        // defaults
        state_next = state;
        for (i=0; i<16; i=i+1) begin
            channel_next[i] = channel[i];
        end
        byte_cnt_next = byte_cnt;
        flags_next = flags;
        frame_rdy_next = frame_rdy;
        frame_err_next = frame_err;
        frame_timeout_next = frame_timeout;
        frame_timer_next = frame_timer;
        for (i=0; i<16; i=i+1) begin
            channel_rev_next[i] = channel_rev[i];
        end

        // make sure ready signal is asserted for one clock cycle only
        if (frame_rdy == 1'b1) begin
            frame_rdy_next = 1'b0;
        end
    
        case (state)
            IDLE: begin
                frame_timer_next = frame_timer + 1;
                if (frame_timer > FRAME_TIMEOUT_TICKS) begin
                    // timeout
                    state_next = TIMEOUT;
                end else if (err_i == 1'b1) begin
                    state_next = ERROR;
                end else if ((rdy_i == 1'b1) && (uart_i == START_BYTE)) begin
                    frame_timer_next = 0;
                    state_next = DATA;
                    byte_cnt_next = 0;
                end 
            end
            DATA: begin
                frame_timer_next = frame_timer + 1;
                if (frame_timer > FRAME_TIMEOUT_TICKS) begin
                    // timeout
                    state_next = TIMEOUT;
                end else if (err_i == 1'b1) begin
                    state_next = ERROR;
                end else if (rdy_i == 1'b1) begin
                    frame_timer_next = 0;
                    byte_cnt_next = byte_cnt + 1;
                    if (byte_cnt == 0) begin
                        channel_next[0][10:3] = uart_i[7:0];
                    end else if (byte_cnt == 1) begin
                        channel_next[0][2:0] = uart_i[7:5];
                        channel_next[1][10:6] = uart_i[4:0];
                    end else if (byte_cnt == 2) begin
                        channel_next[1][5:0] = uart_i[7:2];
                        channel_next[2][10:9] = uart_i[1:0];
                    end else if (byte_cnt == 3) begin
                        channel_next[2][8:1] = uart_i[7:0];
                    end else if (byte_cnt == 4) begin
                        channel_next[2][0] = uart_i[7];
                        channel_next[3][10:4] = uart_i[6:0];
                    end else if (byte_cnt == 5) begin
                        channel_next[3][3:0] = uart_i[7:4];
                        channel_next[4][10:7] = uart_i[3:0];
                    end else if (byte_cnt == 6) begin
                        channel_next[4][6:0] = uart_i[7:1];
                        channel_next[5][10] = uart_i[0];
                    end else if (byte_cnt == 7) begin
                        channel_next[5][9:2] = uart_i[7:0];
                    end else if (byte_cnt == 8) begin
                        channel_next[5][1:0] = uart_i[7:6];
                        channel_next[6][10:5] = uart_i[5:0];
                    end else if (byte_cnt == 9) begin
                        channel_next[6][4:0] = uart_i[7:3];
                        channel_next[7][10:8] = uart_i[2:0];
                    end else if (byte_cnt == 10) begin
                        channel_next[7][7:0] = uart_i[7:0]; 
                    end else if (byte_cnt == 11) begin
                        channel_next[8][10:3] = uart_i[7:0];
                    end else if (byte_cnt == 12) begin
                        channel_next[8][2:0] = uart_i[7:5];
                        channel_next[9][10:6] = uart_i[4:0];
                    end else if (byte_cnt == 13) begin
                        channel_next[9][5:0] = uart_i[7:2];
                        channel_next[10][10:9] = uart_i[1:0];
                    end else if (byte_cnt == 14) begin
                        channel_next[10][8:1] = uart_i[7:0];
                    end else if (byte_cnt == 15) begin
                        channel_next[10][0] = uart_i[7];
                        channel_next[11][10:4] = uart_i[6:0];
                    end else if (byte_cnt == 16) begin
                        channel_next[11][3:0] = uart_i[7:4];
                        channel_next[12][10:7] = uart_i[3:0];
                    end else if (byte_cnt == 17) begin
                        channel_next[12][6:0] = uart_i[7:1];
                        channel_next[13][10] = uart_i[0];
                    end else if (byte_cnt == 18) begin
                        channel_next[13][9:2] = uart_i[7:0];
                    end else if (byte_cnt == 19) begin
                        channel_next[13][1:0] = uart_i[7:6];
                        channel_next[14][10:5] = uart_i[5:0];
                    end else if (byte_cnt == 20) begin
                        channel_next[14][4:0] = uart_i[7:3];
                        channel_next[15][10:8] = uart_i[2:0];
                    end else if (byte_cnt == 21) begin
                        channel_next[15][7:0] = uart_i[7:0];
                    end else if (byte_cnt == 22) begin
                        flags_next = uart_i[7:0];
                    end else if ((byte_cnt == 23) && (uart_i == END_BYTE)) begin
                        // frame valid and ready
                        frame_timeout_next = 1'b0;
                        frame_rdy_next = 1'b1;
                        // reverse bit order for each channel
                        for (i=0; i<16; i=i+1) begin
                            for (j=0; j<11; j=j+1) begin
                                channel_rev_next[i][j] = channel[i][(11-1)-j];
                            end
                        end
                        state_next = IDLE;
                    end else begin
                        state_next = ERROR;
                    end
                end
            end
            ERROR: begin
                frame_err_next = 1'b1;
            end
            TIMEOUT: begin
                frame_timeout_next = 1'b1;
                if (err_i == 1'b1) begin
                    state_next = ERROR;
                end else if ((rdy_i == 1'b1) && (uart_i == START_BYTE)) begin
                    frame_timer_next = 0;
                    state_next = DATA;
                    byte_cnt_next = 0;
                end 
            end
            default:
                frame_err_next = 1'b1;
        endcase
    end

    assign channel_1_o = channel_rev[0];
    assign channel_2_o = channel_rev[1];
    assign channel_3_o = channel_rev[2];
    assign channel_4_o = channel_rev[3];
    assign channel_5_o = channel_rev[4];
    assign channel_6_o = channel_rev[5];
    assign channel_7_o = channel_rev[6];
    assign channel_8_o = channel_rev[7];
    assign channel_9_o = channel_rev[8];
    assign channel_10_o = channel_rev[9];
    assign channel_11_o = channel_rev[10];
    assign channel_12_o = channel_rev[11];
    assign channel_13_o = channel_rev[12];
    assign channel_14_o = channel_rev[13];
    assign channel_15_o = channel_rev[14];
    assign channel_16_o = channel_rev[15];
    assign flags_o = flags;
    assign frame_rdy_o = frame_rdy;
    assign frame_err_o = frame_err;
    assign frame_timeout_o = frame_timeout;
endmodule
