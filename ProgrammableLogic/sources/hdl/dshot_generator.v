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
// D-Shot frame generator
//
//////////////////////////////////////////////////////////////////////////////////


module dshot_generator(
    input           clk_i,
    input           rst_ni,
    input           arm_i,
    input [10:0]    throttle_i,
    input           tlm_i,
    output          dshot_o
    );

    // clock counter
    reg [31:0] clk_cnt, clk_cnt_next;

    // dshot 1200
    localparam FRAME_RATE_TICKS = 10000;  // 10 kHz 
    localparam PWM_RATE_TICKS   = 5;      // 20 MHz -> results in bit rate of 1'250 kBit/s

    // FSM
    localparam
        INACTIVE    = 2'b00,
        IDLE        = 2'b01,
        SEND        = 2'b10,
        ERROR       = 2'b11;
    reg [1:0] state, state_next;

    // internal registers
    reg [4:0] bit_index, bit_index_next;
    reg [2:0] pwm_index, pwm_index_next;
    reg [15:0] dshot_frame, dshot_frame_next;
    reg dshot, dshot_next;

    // internal registers
    always @(posedge clk_i, negedge rst_ni) begin
        if (rst_ni == 'b0) begin
            clk_cnt <= 1;
            bit_index <= 0;
            pwm_index <= 0;
            dshot_frame <= 16'h00;
            dshot <= 1'b0;
        end else begin
            clk_cnt <= clk_cnt_next;
            bit_index <= bit_index_next;
            pwm_index <= pwm_index_next;
            dshot_frame <= dshot_frame_next;
            dshot <= dshot_next;
        end
    end

    // assign next state
    always @ (posedge clk_i, negedge rst_ni) begin
        if (rst_ni == 'b0) begin
            state <= INACTIVE;
        end else begin
            state <= state_next;
        end
    end

    // next state logic
    always @(*) begin
        // defaults
        state_next = state;
        clk_cnt_next = clk_cnt;
        bit_index_next = bit_index;
        pwm_index_next = pwm_index;
        dshot_frame_next = dshot_frame;
        dshot_next = dshot;

        case (state)
            INACTIVE: begin
                if (arm_i == 1'b1) begin
                    state_next = IDLE;
                    clk_cnt_next = 1;
                end
            end
            IDLE: begin
                clk_cnt_next = clk_cnt + 1;
                if (arm_i == 1'b0) begin
                    state_next = INACTIVE;
                end else if (clk_cnt >= FRAME_RATE_TICKS) begin
                    state_next = SEND;
                    clk_cnt_next = 1;
                    bit_index_next = 0;
                    pwm_index_next = 0;
                    dshot_frame_next[15:5] = throttle_i;
                    dshot_frame_next[4] = tlm_i;
                    // compute CRC
                    dshot_frame_next[3:0] = ({throttle_i, tlm_i} ^ ({throttle_i, tlm_i} >> 4) ^ ({throttle_i, tlm_i} >> 8)) & 8'h0F;
                end
            end
            SEND: begin
                clk_cnt_next = clk_cnt + 1;
                if (bit_index < 16) begin
                    if (clk_cnt >= PWM_RATE_TICKS) begin
                        clk_cnt_next = 1;
                        pwm_index_next = pwm_index + 1;
                        if (pwm_index < 3) begin
                            dshot_next = 1'b1;
                        end else if (pwm_index < 6) begin
                            if (dshot_frame[15-bit_index] == 1'b0) begin
                                dshot_next = 1'b0;
                            end else begin
                                dshot_next = 1'b1;
                            end
                        end else if (pwm_index < 7) begin
                            dshot_next = 1'b0;
                        end else if (pwm_index == 7) begin
                            dshot_next = 1'b0;
                            pwm_index_next = 0;
                            bit_index_next = bit_index + 1;
                        end else begin
                            // should never reach this
                        end
                    end
                end else begin
                    state_next = IDLE;
                    dshot_next = 1'b0;
                end
            end
            default: begin
                // should never reach this
            end
        endcase
    end

    assign dshot_o = dshot;
endmodule
