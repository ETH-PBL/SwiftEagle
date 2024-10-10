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
// interconnect logic for motors signals
//
//////////////////////////////////////////////////////////////////////////////////


module motors_interconnect(
    input [31:0]    reg_00,
    input [31:0]    reg_04,
    input [31:0]    reg_05,
    input [31:0]    reg_06,
    input [31:0]    reg_07,
    input [31:0]    reg_08,
    output          arm_0,
    output          arm_1,
    output          arm_2,
    output          arm_3,
    output          tlm_0,
    output          tlm_1,
    output          tlm_2,
    output          tlm_3,
    output [10:0]   throttle_0,
    output [10:0]   throttle_1,
    output [10:0]   throttle_2,
    output [10:0]   throttle_3
    );

    assign arm_0 = reg_00[0];
    assign arm_1 = reg_00[1];
    assign arm_2 = reg_00[2];
    assign arm_3 = reg_00[3];

    assign tlm_0 = reg_08[0];
    assign tlm_1 = reg_08[1];
    assign tlm_2 = reg_08[2];
    assign tlm_3 = reg_08[3];

    assign throttle_0 = reg_04[10:0];
    assign throttle_1 = reg_05[10:0];
    assign throttle_2 = reg_06[10:0];
    assign throttle_3 = reg_07[10:0];
endmodule
