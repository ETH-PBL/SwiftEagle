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
// evt top
//
//////////////////////////////////////////////////////////////////////////////////

module evt_top #(
    parameter integer PIXEL_BITDEPTH = 16,
    parameter integer PIXEL_FRACTIONAL_SIZE = 8,
    parameter integer PARAMETER_FRACTIONAL_SIZE = 12,
    parameter integer IMAGE_COLUMNS = 160,
    parameter integer IMAGE_ROWS = 160,
    parameter integer SCALE_DOWN_BY = 2,
    parameter integer FILTER_UPDATE_TICKS = 1000000,
    parameter integer VIDEO_SCALE_RGB_BY = 8,
    parameter integer AXILITE_DATA_WIDTH = 32,
    parameter integer AXILITE_ADDR_WIDTH = 7) (

    input wire clk_i,
    input wire rst_ni,

    input wire imu_int_i,
    output wire exttrig_o,
    output wire trig_event_o,
    output wire [4:0] trig_id_o,
    output wire trig_pol_o,

    input wire s00_axis_aclk,
    input wire s00_axis_aresetn,
    output wire s00_axis_tready,
    input wire [31:0] s00_axis_tdata,
    input wire s00_axis_tlast,
    input wire s00_axis_tvalid,

    input wire m00_axis_aclk,
    input wire m00_axis_aresetn,
    output wire m00_axis_tvalid,
    output wire [31:0] m00_axis_tdata,
    output wire m00_axis_tlast,
    output wire m00_axis_tuser,
    input wire m00_axis_tready,

    input wire S_AXI_ACLK,
    input wire S_AXI_ARESETN,
    input wire [AXILITE_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
    input wire [2 : 0] S_AXI_AWPROT,
    input wire S_AXI_AWVALID,
    output wire S_AXI_AWREADY,
    input wire [AXILITE_DATA_WIDTH-1 : 0] S_AXI_WDATA,
    input wire [(AXILITE_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
    input wire S_AXI_WVALID,
    output wire S_AXI_WREADY,
    output wire [1 : 0] S_AXI_BRESP,
    output wire S_AXI_BVALID,
    input wire S_AXI_BREADY,
    input wire [AXILITE_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
    input wire [2 : 0] S_AXI_ARPROT,
    input wire S_AXI_ARVALID,
    output wire S_AXI_ARREADY,
    output wire [AXILITE_DATA_WIDTH-1 : 0] S_AXI_RDATA,
    output wire [1 : 0] S_AXI_RRESP,
    output wire S_AXI_RVALID,
    input wire S_AXI_RREADY
    );

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

    wire [clogb2(IMAGE_ROWS-1)-1:0] mem_read_address [IMAGE_COLUMNS-1:0];
    wire signed [PIXEL_BITDEPTH-1:0] mem_read_data [IMAGE_COLUMNS-1:0];

    evt_decoder #(
        .PIXEL_BITDEPTH(PIXEL_BITDEPTH),
        .PIXEL_FRACTIONAL_SIZE(PIXEL_FRACTIONAL_SIZE),
        .PARAMETER_FRACTIONAL_SIZE(PARAMETER_FRACTIONAL_SIZE),
        .IMAGE_COLUMNS(IMAGE_COLUMNS),
        .IMAGE_ROWS(IMAGE_ROWS),
        .SCALE_DOWN_BY(SCALE_DOWN_BY),
        .FILTER_UPDATE_TICKS(FILTER_UPDATE_TICKS),
        .AXILITE_DATA_WIDTH(AXILITE_DATA_WIDTH),
        .AXILITE_ADDR_WIDTH(AXILITE_ADDR_WIDTH))
    evt_decoder_i (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .imu_int_i(imu_int_i),
        .exttrig_o(exttrig_o),
        .trig_event_o(trig_event_o),
        .trig_id_o(trig_id_o),
        .trig_pol_o(trig_pol_o),
        .mem_read_address_i(mem_read_address),
        .mem_read_data_o(mem_read_data),
        .s00_axis_aclk(s00_axis_aclk),
        .s00_axis_aresetn(s00_axis_aresetn),
        .s00_axis_tready(s00_axis_tready),
        .s00_axis_tdata(s00_axis_tdata),
        .s00_axis_tlast(s00_axis_tlast),
        .s00_axis_tvalid(s00_axis_tvalid),
        .S_AXI_ACLK(S_AXI_ACLK),
        .S_AXI_ARESETN(S_AXI_ARESETN),
        .S_AXI_AWADDR(S_AXI_AWADDR),
        .S_AXI_AWPROT(S_AXI_AWPROT),
        .S_AXI_AWVALID(S_AXI_AWVALID),
        .S_AXI_AWREADY(S_AXI_AWREADY),
        .S_AXI_WDATA(S_AXI_WDATA),
        .S_AXI_WSTRB(S_AXI_WSTRB),
        .S_AXI_WVALID(S_AXI_WVALID),
        .S_AXI_WREADY(S_AXI_WREADY),
        .S_AXI_BRESP(S_AXI_BRESP),
        .S_AXI_BVALID(S_AXI_BVALID),
        .S_AXI_BREADY(S_AXI_BREADY),
        .S_AXI_ARADDR(S_AXI_ARADDR),
        .S_AXI_ARPROT(S_AXI_ARPROT),
        .S_AXI_ARVALID(S_AXI_ARVALID),
        .S_AXI_ARREADY(S_AXI_ARREADY),
        .S_AXI_RDATA(S_AXI_RDATA),
        .S_AXI_RRESP(S_AXI_RRESP),
        .S_AXI_RVALID(S_AXI_RVALID),
        .S_AXI_RREADY(S_AXI_RREADY));

    video_stream_generator #(
        .PIXEL_BITDEPTH(PIXEL_BITDEPTH),
        .PIXEL_FRACTIONAL_SIZE(PIXEL_FRACTIONAL_SIZE),
        .IMAGE_COLUMNS(IMAGE_COLUMNS),
        .IMAGE_ROWS(IMAGE_ROWS),
        .VIDEO_SCALE_RGB_BY(VIDEO_SCALE_RGB_BY))
    video_stream_generator_i (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .mem_read_address_o(mem_read_address),
        .mem_read_data_i(mem_read_data),
        .m00_axis_aclk(m00_axis_aclk),
        .m00_axis_aresetn(m00_axis_aresetn),
        .m00_axis_tvalid(m00_axis_tvalid),
        .m00_axis_tdata(m00_axis_tdata),
        .m00_axis_tlast(m00_axis_tlast),
        .m00_axis_tuser(m00_axis_tuser),
        .m00_axis_tready(m00_axis_tready));
endmodule
