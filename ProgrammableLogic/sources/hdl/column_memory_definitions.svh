/*
 * Copyright (C) 2024 ETH Zurich
 * All rights reserved.
 *
 * This software may be modified and distributed under the terms
 * of the GPL-3.0 license.  See the LICENSE file for details.
 */
 
// actions
localparam
    NONE        = 2'b00,
    ACCUMULATE  = 2'b01,
    FILTER      = 2'b10,
    CLEAR       = 2'b11;

// polarity
localparam
    POL_ZERO       = 2'b00,
    POL_POSITIVE   = 2'b01,
    POL_NEGATIVE   = 2'b10;
