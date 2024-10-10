/*
 * Copyright (C) 2024 ETH Zurich
 * All rights reserved.
 *
 * This software may be modified and distributed under the terms
 * of the GPL-3.0 license.  See the LICENSE file for details.
 */
 
module column_memory #(
    parameter integer ADDR_WIDTH = 8,
    parameter integer n = 16,
    parameter integer l = 8,
    parameter integer q = 12) (
    clk, rst_ni, addra, addrb, dob, action, pol, in);

    `include "column_memory_definitions.svh"

    // synthesis translate_off
    integer i;
    // synthesis translate_on

    input clk, rst_ni;
    input [2:0] action;
    input [1:0] pol;
    input [(n-q-2):0] in;
    input [ADDR_WIDTH-1:0] addra, addrb;
    output reg signed [n-1:0] dob;
    reg signed [n-1:0] y [(2**ADDR_WIDTH)-1:0];
    // filter state
    reg signed [n-1:0] state [(2**ADDR_WIDTH)-1:0];

    // pipeline registers
    reg [2:0] action_pipe;
    reg signed [n+q-l-1:0] x;
    reg [ADDR_WIDTH-1:0] addra_pipe;


    //////////////////////////////////////////////////
    //
    // data representation
    // 
    //////////////////////////////////////////////////

    // parameters (a1, b0, b1)

    //     sign ext.
    //        q-l     sign                   fractional q
    //     _________   |           _________________________________
    //    /         \  v          /                                 \
    //   |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
    //                \_____________________________________________/
    //                                data width n             

    // note: the parameters here assume n=16, l=8, q=12
    localparam
        a1  = 20'shFF010,   // a1 = -0.99609375
        b0  = 20'sh01000,   // b0 = 1
        b1  = 20'sh00000;   // b1 = 0


    // data in memory

    //    
    //    sign                         fractional l
    //     |                       _____________________
    //     v                      /                     \
    //   |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
    //    \_____________________________________________/
    //                      data width n             


    // data in memory -> aligned with input / parameters

    //                                                      LSB ext.    
    //    sign                         fractional l           q-l
    //     |                       _____________________   _________
    //     v                      /                     \ /         \
    //   |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  | 0| 0| 0| 0|
    //    \_____________________________________________/
    //                      data width n             


    // some other parameters

    // n-wide signed vector
    // (max/min values in memory)
    localparam
        N_SIGNED_MAX    = $signed({1'b0, {(n-1){1'b1}}}),
        N_SIGNED_MIN    = $signed({1'b1, {(n-1){1'b0}}});

    // (n+q-l)-wide signed vector
    // (max/min values used in case of over/underflow)
    localparam
        OVERFLOW_MAX    = $signed({N_SIGNED_MAX, {(q-l){1'b1}}}),
        OVERFLOW_MIN    = $signed({N_SIGNED_MIN, {(q-l){1'b0}}});

    // 2*(n+q-l)-wide signed vector
    // (used for overflow detection during multiplication)
    localparam
        MULT_MAX    = $signed({{(n-l){1'b0}}, OVERFLOW_MAX, {q{1'b1}}}),
        MULT_MIN    = $signed({{(n-l){1'b1}}, OVERFLOW_MIN, {q{1'b0}}});


    //////////////////////////////////////////////////
    //
    // signed add function
    //
    // - saturates if overflow / underflow
    // 
    //////////////////////////////////////////////////

    function reg signed [(n+q-l-1):0] add (input reg signed [(n+q-l-1):0] a, b);   
        begin
            add = a + b;

            // saturate if overflow
            if (a > 0 && b > 0 && add < 0) begin
                add = OVERFLOW_MAX;
            end
            // saturate if underflow
            if (a < 0 && b < 0 && add > 0) begin
                add = OVERFLOW_MIN;
            end
        end
    endfunction


    //////////////////////////////////////////////////
    //
    // signed multiply function
    //
    // - saturates if overflow / underflow
    // 
    //////////////////////////////////////////////////

    function reg signed [(n+q-l-1):0] multiply (input reg signed [(n+q-l-1):0] a, b);
        reg signed [(2*(n+q-l)-1):0] ab;
        begin
            ab = a * b;
            // truncate
            multiply = $signed(ab[2*(n+q-l)-(n-l)-1:q]);

            // saturate if overflow
            if (ab > MULT_MAX) begin
                multiply = OVERFLOW_MAX;
            end
            // saturate if underflow
            if (ab < MULT_MIN) begin
                multiply = OVERFLOW_MIN;
            end
        end
    endfunction


    //////////////////////////////////////////////////
    //
    // truncate function
    //
    //////////////////////////////////////////////////

    function reg signed [(n-1):0] truncate (input reg signed [(n+q-l-1):0] a);
        begin
            truncate = $signed(a[n+q-l-1:q-l]);
        end
    endfunction


    //////////////////////////////////////////////////
    //
    // align function
    //
    //////////////////////////////////////////////////

    function reg signed [(n+q-l-1):0] align (input reg signed [(n-1):0] a);
        begin
            align = $signed({a, {(q-l){1'b0}}});
        end
    endfunction


    //////////////////////////////////////////////////
    //
    // format input function
    //
    //////////////////////////////////////////////////

    function reg signed [(n+q-l-1):0] format_input (input reg signed [(n-q-2):0] a, input reg [1:0] pol);
        begin
            if (pol == POL_ZERO) begin
                format_input = $signed({(n+q-l){1'b0}});
            end else if (pol == POL_NEGATIVE) begin
                format_input = $signed({{(q-l+1){1'b1}}, ~a+1, {q{1'b0}}});
            end else if (pol == POL_POSITIVE) begin
                format_input = $signed({{(q-l+1){1'b0}}, a, {q{1'b0}}});
            end else begin
                // should never reach here
                format_input = 0;
            end
        end
    endfunction


    //////////////////////////////////////////////////
    //
    // Memory implementation
    // 
    //////////////////////////////////////////////////

    always @(posedge clk, negedge rst_ni) begin
        if (rst_ni == 1'b0) begin
            action_pipe <= NONE;
            x <= 0;
            addra_pipe <= 0;
            // synthesis translate_off
            for (i=0; i<(2**ADDR_WIDTH); i=i+1) begin
                y[i] <= 0;
                state[i] <= 0;
            end
            // synthesis translate_on
        end else begin
            action_pipe <= action;
            x <= format_input(in, pol);
            addra_pipe <= addra;
        end
    end

    always @(posedge clk) begin
        case (action_pipe)
            ACCUMULATE: begin

                // 1. read memory and align (using LSB extension)
                // 2. accumulate
                // 3. truncate and write back to memory
                y[addra_pipe] <= truncate(add(align(y[addra_pipe]), x));
            end
            FILTER: begin
                //
                // filter transfer function:
                //
                //  yi     b0 + z^-1*b1
                // ---- = --------------
                //  xi     1 + z^-1*a1
                //
                //
                // filter implementation:
                //
                //  xi ---->o-------------+---- b0 ---->o----> yi
                //        + ^             |           + ^
                //          |             |             |
                //          |            z^-1           |
                //          |             |             |
                //          |             |             |
                //          +---- -a1 ----+---- b1 -----+
                //

                // 1. read memory and align (using LSB extension)
                // 2. filter step
                // 3. truncate and write back to memory
                y[addra_pipe] <= truncate(add(multiply(add(x, multiply(align(state[addra_pipe]), -a1)), b0),
                                            multiply(align(state[addra_pipe]), b1)));
                // save filter state for next filter step
                state[addra_pipe] <= truncate(add(x, multiply(align(state[addra_pipe]), -a1)));
            end
            CLEAR: begin
                y[addra_pipe] <= 0;
            end
            NONE: begin
            end
            default: begin
            end
        endcase
    end

    // read
    always @(posedge clk) begin
        dob <= y[addrb];
    end
endmodule
