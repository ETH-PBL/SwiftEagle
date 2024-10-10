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
// video stream generator
//
//////////////////////////////////////////////////////////////////////////////////

module video_stream_generator #(
    parameter integer PIXEL_BITDEPTH = 16,
    parameter integer PIXEL_FRACTIONAL_SIZE = 8,
    parameter integer IMAGE_COLUMNS = 160,
    parameter integer IMAGE_ROWS = 160,
    parameter integer VIDEO_SCALE_RGB_BY = 8) (

    // inputs
    input clk_i,
    input rst_ni,

    // memory read port
    output reg [clogb2(IMAGE_ROWS-1)-1:0] mem_read_address_o [IMAGE_COLUMNS-1:0],
    input wire signed [PIXEL_BITDEPTH-1:0] mem_read_data_i [IMAGE_COLUMNS-1:0],

    // axi stream master
    input wire m00_axis_aclk,
    input wire m00_axis_aresetn,
    output reg m00_axis_tvalid,
    output reg [31:0] m00_axis_tdata,
    output reg m00_axis_tlast,
    output reg m00_axis_tuser,
    input wire m00_axis_tready);

    integer j;

    //////////////////////////////////////////////////
    //
    // clogb2 function
    //
    // returns an integer which has the value of the
    // ceiling of the log base 2
    // 
    //////////////////////////////////////////////////

    function integer clogb2 (input integer bit_depth_in);
        integer bit_depth;
        begin
            bit_depth = bit_depth_in;
            for(clogb2=0; bit_depth>0; clogb2=clogb2+1)
                bit_depth = bit_depth >> 1;
        end
    endfunction


    //////////////////////////////////////////////////
    //
    // video stream generator FSM
    // 
    //////////////////////////////////////////////////

    // states
    localparam
        VIDEO_FSM_INIT  = 2'b00,
        VIDEO_FSM_RUN   = 2'b01,
        VIDEO_FSM_WAIT  = 2'b10;
    reg [1:0] video_fsm_state, video_fsm_state_next;

    // assign next state
    always @ (posedge clk_i, negedge rst_ni) begin
        if (rst_ni == 'b0) begin
            video_fsm_state <= VIDEO_FSM_INIT;
        end else begin
            video_fsm_state <= video_fsm_state_next;
        end
    end

    // registers
    reg [clogb2(IMAGE_ROWS-1)-1:0] video_row, video_row_next;
    reg [clogb2(IMAGE_COLUMNS-1)-1:0] video_column, video_column_next;
    reg tvalid_prev, tlast_prev, tuser_prev;
    reg [31:0] tdata_prev;
    reg [clogb2(IMAGE_ROWS-1)-1:0] mem_stream_address_prev, mem_stream_address_prev_next;

    // registers reset and update
    always @ (posedge clk_i, negedge rst_ni) begin
        if (rst_ni == 'b0) begin
            mem_stream_address_prev <= 0;
            video_column <= 0;
            video_row <= 0;
            tvalid_prev <= 1'b0;
            tlast_prev <= 1'b0;
            tuser_prev <= 1'b0;
            tdata_prev <= 32'b0;
        end else begin
            mem_stream_address_prev <= mem_stream_address_prev_next;
            video_column <= video_column_next;
            video_row <= video_row_next;
            tvalid_prev <= m00_axis_tvalid;
            tlast_prev <= m00_axis_tlast;
            tuser_prev <= m00_axis_tuser;
            tdata_prev <= m00_axis_tdata;
        end
    end

    // assign next state
    always @(*) begin
        video_fsm_state_next = video_fsm_state;
        video_row_next = video_row;
        video_column_next = video_column;
        m00_axis_tvalid = tvalid_prev;
        m00_axis_tlast = tlast_prev;
        m00_axis_tuser = tuser_prev;
        m00_axis_tdata = tdata_prev;
        mem_stream_address_prev_next = mem_stream_address_prev;
        for (j=0; j<IMAGE_COLUMNS; j=j+1) begin
            mem_read_address_o[j] = mem_stream_address_prev;
        end

        case (video_fsm_state)
            VIDEO_FSM_INIT: begin
                // wait one clock cycle such that memory output 
                // is available next clock
                video_fsm_state_next = VIDEO_FSM_RUN;
            end
            VIDEO_FSM_RUN: begin
                video_column_next = video_column + 1;
                m00_axis_tvalid = 1'b1;
                m00_axis_tlast = 1'b0;
                m00_axis_tuser = 1'b0;
                // convert to 10-bit RGB
                if (mem_read_data_i[video_column] >= $signed({{(PIXEL_BITDEPTH-PIXEL_FRACTIONAL_SIZE-1){1'b0}}, 1'b1, {PIXEL_FRACTIONAL_SIZE{1'b0}}})) begin
                    // values larger than +1 => white
                    m00_axis_tdata = {2'b00,
                                    8'hFF,
                                    2'b00,
                                    8'hFF,
                                    2'b00,
                                    8'hFF,
                                    2'b00};
                end else if (mem_read_data_i[video_column] <= $signed({{(PIXEL_BITDEPTH-PIXEL_FRACTIONAL_SIZE){1'b1}}, {PIXEL_FRACTIONAL_SIZE{1'b0}}})) begin
                    // values smaller than -1 => blue
                    m00_axis_tdata = {2'b00,
                                    8'hFF,
                                    2'b00,
                                    8'h00,
                                    2'b00,
                                    8'h00,
                                    2'b00};
                end else begin
                    // values between +/- 1 => black
                    m00_axis_tdata = {2'b00,
                                    8'h00,
                                    2'b00,
                                    8'h00,
                                    2'b00,
                                    8'h00,
                                    2'b00};
                end
                if (video_column == (IMAGE_COLUMNS-1)) begin
                    // end of row reached
                    m00_axis_tlast = 1'b1;
                end
                if ((video_row == 0) && (video_column == 0)) begin
                    // first pixel, trigger new frame
                    m00_axis_tuser = 1'b1;
                end
                if (video_column == (IMAGE_COLUMNS-1)) begin
                    video_column_next = 0;
                    video_row_next = video_row + 1;
                    if (video_row == (IMAGE_ROWS-1)) begin
                        video_row_next = 0;
                    end
                    // next row to read from
                    for (j=0; j<IMAGE_COLUMNS; j=j+1) begin
                        mem_read_address_o[j] = video_row_next;
                    end
                    mem_stream_address_prev_next = video_row_next;
                end
                if (~m00_axis_tready) begin
                    video_fsm_state_next = VIDEO_FSM_WAIT;
                end
            end
            VIDEO_FSM_WAIT: begin
                // wait for tready to be asserted
                if (m00_axis_tready) begin
                    video_fsm_state_next = VIDEO_FSM_RUN;
                end
            end
            default: begin
            end
        endcase
    end
endmodule
