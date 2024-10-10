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
// emergency switch-off motors
//
//////////////////////////////////////////////////////////////////////////////////


module motor_emergency_stop (
    input enable_i,
    input stop_i,
    input [3:0] dshot_i,
    output [3:0] dshot_o
    );

    assign dshot_o = (enable_i && ~stop_i) ? dshot_i : 1'b0;

endmodule
