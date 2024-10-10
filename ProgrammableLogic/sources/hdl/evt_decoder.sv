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
// evt decoder
// 
// specs: https://docs.prophesee.ai/stable/data/encoding_formats/evt21.html
//
//////////////////////////////////////////////////////////////////////////////////

module evt_decoder #(
    parameter integer PIXEL_BITDEPTH = 16,
    parameter integer PIXEL_FRACTIONAL_SIZE = 8,
    parameter integer PARAMETER_FRACTIONAL_SIZE = 12,
    parameter integer IMAGE_COLUMNS = 160,
    parameter integer IMAGE_ROWS = 160,
    parameter integer SCALE_DOWN_BY = 2,
    parameter integer FILTER_UPDATE_TICKS = 1000000,
    parameter integer AXILITE_DATA_WIDTH = 32,
    parameter integer AXILITE_ADDR_WIDTH = 7) (

    // inputs
    input clk_i,
    input rst_ni,
    input imu_int_i,

    // exttrig output
    output exttrig_o,

    // trigger outputs
    output reg trig_event_o,
    output reg [4:0] trig_id_o,
    output reg trig_pol_o,

    // memory read port
    input reg [clogb2(IMAGE_ROWS-1)-1:0] mem_read_address_i [IMAGE_COLUMNS-1:0],
    output wire signed [PIXEL_BITDEPTH-1:0] mem_read_data_o [IMAGE_COLUMNS-1:0],

    // axi stream slave
    input wire s00_axis_aclk,
    input wire s00_axis_aresetn,
    output wire s00_axis_tready,
    input wire [31:0] s00_axis_tdata,
    input wire s00_axis_tlast,
    input wire s00_axis_tvalid,

    // axi lite
    // Global Clock Signal
    input wire  S_AXI_ACLK,
    // Global Reset Signal. This Signal is Active LOW
    input wire  S_AXI_ARESETN,
    // Write address (issued by master, acceped by Slave)
    input wire [AXILITE_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
    // Write channel Protection type. This signal indicates the
    // privilege and security level of the transaction, and whether
    // the transaction is a data access or an instruction access.
    input wire [2 : 0] S_AXI_AWPROT,
    // Write address valid. This signal indicates that the master signaling
    // valid write address and control information.
    input wire  S_AXI_AWVALID,
    // Write address ready. This signal indicates that the slave is ready
    // to accept an address and associated control signals.
    output wire  S_AXI_AWREADY,
    // Write data (issued by master, acceped by Slave) 
    input wire [AXILITE_DATA_WIDTH-1 : 0] S_AXI_WDATA,
    // Write strobes. This signal indicates which byte lanes hold
    // valid data. There is one write strobe bit for each eight
    // bits of the write data bus.    
    input wire [(AXILITE_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
    // Write valid. This signal indicates that valid write
    // data and strobes are available.
    input wire  S_AXI_WVALID,
    // Write ready. This signal indicates that the slave
    // can accept the write data.
    output wire  S_AXI_WREADY,
    // Write response. This signal indicates the status
    // of the write transaction.
    output wire [1 : 0] S_AXI_BRESP,
    // Write response valid. This signal indicates that the channel
    // is signaling a valid write response.
    output wire  S_AXI_BVALID,
    // Response ready. This signal indicates that the master
    // can accept a write response.
    input wire  S_AXI_BREADY,
    // Read address (issued by master, acceped by Slave)
    input wire [AXILITE_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
    // Protection type. This signal indicates the privilege
    // and security level of the transaction, and whether the
    // transaction is a data access or an instruction access.
    input wire [2 : 0] S_AXI_ARPROT,
    // Read address valid. This signal indicates that the channel
    // is signaling valid read address and control information.
    input wire  S_AXI_ARVALID,
    // Read address ready. This signal indicates that the slave is
    // ready to accept an address and associated control signals.
    output wire  S_AXI_ARREADY,
    // Read data (issued by slave)
    output wire [AXILITE_DATA_WIDTH-1 : 0] S_AXI_RDATA,
    // Read response. This signal indicates the status of the
    // read transfer.
    output wire [1 : 0] S_AXI_RRESP,
    // Read valid. This signal indicates that the channel is
    // signaling the required read data.
    output wire  S_AXI_RVALID,
    // Read ready. This signal indicates that the master can
    // accept the read data and response information.
    input wire  S_AXI_RREADY
    );

    `include "column_memory_definitions.svh"

    integer j, k, cnt;

    //////////////////////////////////////////////////
    //
    // event types
    // 
    //////////////////////////////////////////////////

    localparam
        EVT_NEG         = 4'b0000,
        EVT_POS         = 4'b0001,
        EVT_TIME_HIGH   = 4'b1000,
        EXT_TRIGGER     = 4'b1010,
        OTHERS          = 4'b1110,
        CONTINUED       = 4'b1111;


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
    // AXILITE registers
    // 
    //////////////////////////////////////////////////

    //-- Number of Slave Registers 20
    reg [AXILITE_DATA_WIDTH-1:0] axilite_status, axilite_status_next;
    reg [AXILITE_DATA_WIDTH-1:0] axilite_control, axilite_control_next;
    reg [AXILITE_DATA_WIDTH-1:0] slv_reg2;
    reg [AXILITE_DATA_WIDTH-1:0] slv_reg3;
    reg [AXILITE_DATA_WIDTH-1:0] slv_reg4;
    reg [AXILITE_DATA_WIDTH-1:0] slv_reg5;
    reg [AXILITE_DATA_WIDTH-1:0] slv_reg6;
    reg [AXILITE_DATA_WIDTH-1:0] slv_reg7;
    reg [AXILITE_DATA_WIDTH-1:0] slv_reg8;
    reg [AXILITE_DATA_WIDTH-1:0] slv_reg9;
    reg [AXILITE_DATA_WIDTH-1:0] slv_reg10;
    reg [AXILITE_DATA_WIDTH-1:0] slv_reg11;
    reg [AXILITE_DATA_WIDTH-1:0] slv_reg12;
    reg [AXILITE_DATA_WIDTH-1:0] slv_reg13;
    reg [AXILITE_DATA_WIDTH-1:0] slv_reg14;
    reg [AXILITE_DATA_WIDTH-1:0] slv_reg15;
    reg [AXILITE_DATA_WIDTH-1:0] slv_reg16;
    reg [AXILITE_DATA_WIDTH-1:0] slv_reg17;
    reg [AXILITE_DATA_WIDTH-1:0] slv_reg18;
    reg [AXILITE_DATA_WIDTH-1:0] slv_reg19;


    //////////////////////////////////////////////////
    //
    // column memory instantiation
    // 
    //////////////////////////////////////////////////

    // pixel update
    reg [clogb2(IMAGE_ROWS-1)-1:0] mem_address [IMAGE_COLUMNS-1:0];
    reg [2:0] mem_action [IMAGE_COLUMNS-1:0];
    reg [1:0] mem_pol [IMAGE_COLUMNS-1:0];
    reg [(PIXEL_BITDEPTH-PARAMETER_FRACTIONAL_SIZE-2):0] mem_in [IMAGE_COLUMNS-1:0];

    genvar i;

    generate
        for (i=0; i<IMAGE_COLUMNS; i=i+1) begin
            column_memory #(
                .ADDR_WIDTH (clogb2(IMAGE_ROWS-1)),
                .n          (PIXEL_BITDEPTH),
                .l          (PIXEL_FRACTIONAL_SIZE),
                .q          (PARAMETER_FRACTIONAL_SIZE))
            column_memory_i (
                .clk        (clk_i),
                .rst_ni     (rst_ni),
                .action     (mem_action[i]),
                .pol        (mem_pol[i]),
                .in         (mem_in[i]),
                .addra      (mem_address[i]),
                .addrb      (mem_read_address_i[i]),
                .dob        (mem_read_data_o[i])
            );
        end
    endgenerate


    //////////////////////////////////////////////////
    //
    // external trigger (EXTTRIG)
    // 
    //////////////////////////////////////////////////

    // states
    localparam
        EXTTRIG_OFF         = 2'b00,
        EXTTRIG_TURNON      = 2'b01,
        EXTTRIG_ON          = 2'b10,
        EXTTRIG_TURNOFF     = 2'b11;
    reg [1:0] trig_state, trig_state_next;

    reg exttrig, exttrig_next;
    reg imu_int;

    always @ (posedge clk_i, negedge rst_ni) begin
        if (rst_ni == 'b0) begin
            trig_state <= EXTTRIG_OFF;
            exttrig <= 1'b0;
            imu_int <= 1'b0;
        end else begin
            trig_state <= trig_state_next;
            exttrig <= exttrig_next;
            imu_int <= imu_int_i;
        end
    end

    // next state logic
    always @(*) begin
        trig_state_next = trig_state;
        exttrig_next = exttrig;
        axilite_control_next = axilite_control;

        case (trig_state)
            EXTTRIG_OFF: begin
                exttrig_next = 1'b0;
                if (axilite_control[1]) begin
                    trig_state_next = EXTTRIG_TURNON;
                end
            end
            EXTTRIG_TURNON: begin
                // wait for rising edge
                if (imu_int_i && ~imu_int) begin
                    trig_state_next = EXTTRIG_ON;
                end
            end
            EXTTRIG_ON: begin
                exttrig_next = imu_int_i;
                if (~axilite_control[1]) begin
                    trig_state_next = EXTTRIG_TURNOFF;
                end
            end
            EXTTRIG_TURNOFF: begin
                // gracefully wait for falling edge
                if (~imu_int_i) begin
                    trig_state_next = EXTTRIG_OFF;
                end
            end
        endcase
    end

    assign exttrig_o = exttrig;


    //////////////////////////////////////////////////
    //
    // evt decoder + filter FSM
    // 
    //////////////////////////////////////////////////

    // states
    localparam
        IDLE                = 2'b00,
        EVENT               = 2'b01,
        WRITE               = 2'b10,
        ERROR               = 2'b11;
    reg [1:0] state, state_next;

    localparam
        FILTER_IDLE     = 2'b00,
        FILTER_READ     = 2'b01,
        FILTER_STEP     = 2'b10;
    reg [1:0] filter_state, filter_state_next;


    // assign next state
    always @ (posedge clk_i, negedge rst_ni) begin
        if (rst_ni == 'b0) begin
            state <= IDLE;
            filter_state <= FILTER_IDLE;
        end else begin
            state <= state_next;
            filter_state <= filter_state_next;
        end
    end

    // axi output assignments
    assign s00_axis_tready = 1'b1;

    // registers
    reg [31:0] data_lsb, data_lsb_next;
    reg [10:0] x, x_next;
    reg [10:0] y, y_next;
    reg pol, pol_next;
    reg [31:0] vect, vect_next;
    reg [clogb2(IMAGE_ROWS-1)-1:0] filter_row, filter_row_next;
    reg [clogb2(IMAGE_ROWS-1)-1:0] filter_address_read, filter_address_read_next;
    reg [31:0] filter_timer, filter_timer_next;

    // registers reset and update
    always @ (posedge clk_i, negedge rst_ni) begin
        if (rst_ni == 'b0) begin
            data_lsb <= 32'b0;
            x <= 0;
            y <= 0;
            pol <= 1'b0;
            vect <= 32'b0;
            filter_row <= 0;
            filter_address_read <= 0;
            filter_timer <= 0;
        end else begin
            data_lsb <= data_lsb_next;
            x <= x_next;
            y <= y_next;
            pol <= pol_next;
            vect <= vect_next;
            filter_row <= filter_row_next;
            filter_address_read <= filter_address_read_next;
            filter_timer <= filter_timer_next;
        end
    end

    // next state logic
    always @(*) begin
        // defaults
        state_next = state;
        filter_state_next = filter_state;
        data_lsb_next = data_lsb;
        x_next = x;
        y_next = y;
        pol_next = pol;
        vect_next = vect;
        trig_event_o = 1'b0;
        trig_id_o = 0;
        trig_pol_o = 1'b0;
        for (j=0; j<IMAGE_COLUMNS; j=j+1) begin
            mem_action[j] = NONE;
            mem_pol[j] = POL_ZERO;
            mem_in[j] = 0;
            mem_address[j] = 0;
        end
        filter_row_next = filter_row;
        filter_address_read_next = filter_address_read;
        filter_timer_next = filter_timer + 1;
        axilite_status_next = axilite_status;


        case (filter_state)
            FILTER_IDLE: begin
                if (filter_timer > FILTER_UPDATE_TICKS) begin
                    filter_timer_next = 0;
                    filter_state_next = FILTER_READ;
                end
            end
            FILTER_READ: begin
                // read current
                for (j=0; j<IMAGE_COLUMNS; j=j+1) begin
                    mem_action[j] = NONE;
                    mem_address[j] = filter_row;
                end
                filter_address_read_next = filter_row;
                filter_state_next = FILTER_STEP;
            end
            FILTER_STEP: begin
                // apply filter step
                for (j=0; j<IMAGE_COLUMNS; j=j+1) begin
                    // do only apply filter if address (i.e. row)
                    // of column j has not changed during last clock cycle
                    if (filter_row == filter_address_read) begin
                        mem_action[j] = FILTER;
                        mem_address[j] = filter_row;
                    end else begin
                        mem_action[j] = NONE;
                    end
                end
                filter_state_next = FILTER_READ;

                filter_row_next = filter_row + 1;
                if (filter_row == (IMAGE_ROWS-1)) begin
                    filter_row_next = 0;
                    filter_state_next = FILTER_IDLE;
                end
            end
            default: begin
                // should never reach here
                axilite_status_next = axilite_status | 32'h01;
            end
        endcase


        case (state)
            IDLE: begin
                // wait for lower word
                if (s00_axis_tvalid) begin
                    state_next = EVENT;
                    data_lsb_next = s00_axis_tdata;
                end
            end
            EVENT: begin
                // wait for upper word
                if (s00_axis_tvalid) begin
                    // choose action according to event type
                    case (s00_axis_tdata[31:28])
                        EVT_NEG: begin
                            // burst of up to 32 events
                            state_next = WRITE;
                            x_next = s00_axis_tdata[21:11] >> clogb2(SCALE_DOWN_BY-1);
                            y_next = s00_axis_tdata[10:0] >> clogb2(SCALE_DOWN_BY-1);
                            pol_next = 1'b0;
                            vect_next = data_lsb;
                            for (j=0; j<(32 >> clogb2(SCALE_DOWN_BY-1)); j=j+1) begin
                                mem_action[x_next + j] = NONE;
                                mem_address[x_next + j] = y_next;
                            end
                        end
                        EVT_POS: begin
                            // burst of up to 32 events
                            state_next = WRITE;
                            x_next = s00_axis_tdata[21:11] >> clogb2(SCALE_DOWN_BY-1);
                            y_next = s00_axis_tdata[10:0] >> clogb2(SCALE_DOWN_BY-1);
                            pol_next = 1'b1;
                            vect_next = data_lsb;
                            for (j=0; j<(32 >> clogb2(SCALE_DOWN_BY-1)); j=j+1) begin
                                mem_action[x_next + j] = NONE;
                                mem_address[x_next + j] = y_next;
                            end
                        end
                        EVT_TIME_HIGH: begin
                            // not implemented
                            state_next = IDLE;
                        end
                        EXT_TRIGGER: begin
                            state_next = IDLE;
                            trig_event_o = 1'b1;
                            trig_id_o = s00_axis_tdata[12:8];
                            trig_pol_o = s00_axis_tdata[0];
                            state_next = IDLE;
                        end
                        OTHERS: begin
                            // not implemented
                            state_next = IDLE;
                        end
                        CONTINUED: begin
                            // not implemented
                            state_next = IDLE;
                        end
                        default:
                            // unspecified event
                            state_next = ERROR;
                    endcase
                end
            end
            WRITE: begin
                for (j=0; j<(32 >> clogb2(SCALE_DOWN_BY-1)); j=j+1) begin
                    cnt = 0;
                    for (k=0; k<SCALE_DOWN_BY; k=k+1) begin
                        if (vect & (32'b1 << (j*SCALE_DOWN_BY+k))) begin
                            cnt = cnt + 1;
                        end
                    end
                    mem_in[x + j] = cnt;
                    mem_pol[x + j] = pol? POL_POSITIVE : POL_NEGATIVE;
                    mem_action[x + j] = ACCUMULATE;
                    mem_address[x + j] = y;
                end
                // wait for lower word
                if (s00_axis_tvalid) begin
                    state_next = EVENT;
                    data_lsb_next = s00_axis_tdata;
                end else begin
                    state_next = IDLE;
                end
            end
            ERROR: begin
                axilite_status_next = axilite_status | 32'h01;
            end
            default: begin
                // should never reach here
                axilite_status_next = axilite_status | 32'h01;
            end
        endcase
    end


    //////////////////////////////////////////////////
    //
    // AXILITE interface
    // 
    //////////////////////////////////////////////////

    // AXI4LITE signals
    reg [AXILITE_ADDR_WIDTH-1:0] axi_awaddr;
    reg axi_awready;
    reg axi_wready;
    reg [1:0] axi_bresp;
    reg axi_bvalid;
    reg [AXILITE_ADDR_WIDTH-1:0] axi_araddr;
    reg axi_arready;
    reg [AXILITE_DATA_WIDTH-1:0] axi_rdata;
    reg [1:0] axi_rresp;
    reg axi_rvalid;

    // Example-specific design signals
    // local parameter for addressing 32 bit / 64 bit AXILITE_DATA_WIDTH
    // ADDR_LSB is used for addressing 32/64 bit registers/memories
    // ADDR_LSB = 2 for 32 bits (n downto 2)
    // ADDR_LSB = 3 for 64 bits (n downto 3)
    localparam integer ADDR_LSB = (AXILITE_DATA_WIDTH/32) + 1;
    localparam integer OPT_MEM_ADDR_BITS = 4;
    //----------------------------------------------
    //-- Signals for user logic register space example
    //------------------------------------------------
    wire slv_reg_rden;
    wire slv_reg_wren;
    reg [AXILITE_DATA_WIDTH-1:0] reg_data_out;
    integer byte_index;
    reg aw_en;

    // I/O Connections assignments

    assign S_AXI_AWREADY = axi_awready;
    assign S_AXI_WREADY	= axi_wready;
    assign S_AXI_BRESP = axi_bresp;
    assign S_AXI_BVALID	= axi_bvalid;
    assign S_AXI_ARREADY = axi_arready;
    assign S_AXI_RDATA = axi_rdata;
    assign S_AXI_RRESP = axi_rresp;
    assign S_AXI_RVALID	= axi_rvalid;
    // Implement axi_awready generation
    // axi_awready is asserted for one S_AXI_ACLK clock cycle when both
    // S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_awready is
    // de-asserted when reset is low.

    always @( posedge S_AXI_ACLK )
    begin
      if ( S_AXI_ARESETN == 1'b0 )
        begin
          axi_awready <= 1'b0;
          aw_en <= 1'b1;
        end 
      else
        begin    
          if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en)
            begin
              // slave is ready to accept write address when 
              // there is a valid write address and write data
              // on the write address and data bus. This design 
              // expects no outstanding transactions. 
              axi_awready <= 1'b1;
              aw_en <= 1'b0;
            end
            else if (S_AXI_BREADY && axi_bvalid)
                begin
                  aw_en <= 1'b1;
                  axi_awready <= 1'b0;
                end
          else           
            begin
              axi_awready <= 1'b0;
            end
        end 
    end       

    // Implement axi_awaddr latching
    // This process is used to latch the address when both 
    // S_AXI_AWVALID and S_AXI_WVALID are valid. 

    always @( posedge S_AXI_ACLK )
    begin
      if ( S_AXI_ARESETN == 1'b0 )
        begin
          axi_awaddr <= 0;
        end 
      else
        begin    
          if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en)
            begin
              // Write Address latching 
              axi_awaddr <= S_AXI_AWADDR;
            end
        end 
    end       

    // Implement axi_wready generation
    // axi_wready is asserted for one S_AXI_ACLK clock cycle when both
    // S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_wready is 
    // de-asserted when reset is low. 

    always @( posedge S_AXI_ACLK )
    begin
      if ( S_AXI_ARESETN == 1'b0 )
        begin
          axi_wready <= 1'b0;
        end 
      else
        begin    
          if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID && aw_en )
            begin
              // slave is ready to accept write data when 
              // there is a valid write address and write data
              // on the write address and data bus. This design 
              // expects no outstanding transactions. 
              axi_wready <= 1'b1;
            end
          else
            begin
              axi_wready <= 1'b0;
            end
        end 
    end       

    // Implement memory mapped register select and write logic generation
    // The write data is accepted and written to memory mapped registers when
    // axi_awready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted. Write strobes are used to
    // select byte enables of slave registers while writing.
    // These registers are cleared when reset (active low) is applied.
    // Slave register write enable is asserted when valid address and data are available
    // and the slave is ready to accept the write address and write data.
    assign slv_reg_wren = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;

    always @( posedge S_AXI_ACLK )
    begin
      if ( S_AXI_ARESETN == 1'b0 )
        begin
          axilite_status <= 0;
          axilite_control <= 0;
          slv_reg2 <= 0;
          slv_reg3 <= 0;
          slv_reg4 <= 0;
          slv_reg5 <= 0;
          slv_reg6 <= 0;
          slv_reg7 <= 0;
          slv_reg8 <= 0;
          slv_reg9 <= 0;
          slv_reg10 <= 0;
          slv_reg11 <= 0;
          slv_reg12 <= 0;
          slv_reg13 <= 0;
          slv_reg14 <= 0;
          slv_reg15 <= 0;
          slv_reg16 <= 0;
          slv_reg17 <= 0;
          slv_reg18 <= 0;
          slv_reg19 <= 0;
        end 
      else begin
        if (slv_reg_wren)
          begin
            case ( axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
              5'h01:
                for ( byte_index = 0; byte_index <= (AXILITE_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                  if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                    // Respective byte enables are asserted as per write strobes 
                    // Slave register 1
                    axilite_control[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                  end  
              5'h02:
                for ( byte_index = 0; byte_index <= (AXILITE_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                  if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                    // Respective byte enables are asserted as per write strobes 
                    // Slave register 2
                    slv_reg2[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                  end  
              5'h03:
                for ( byte_index = 0; byte_index <= (AXILITE_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                  if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                    // Respective byte enables are asserted as per write strobes 
                    // Slave register 3
                    slv_reg3[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                  end  
              5'h04:
                for ( byte_index = 0; byte_index <= (AXILITE_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                  if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                    // Respective byte enables are asserted as per write strobes 
                    // Slave register 4
                    slv_reg4[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                  end  
              5'h05:
                for ( byte_index = 0; byte_index <= (AXILITE_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                  if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                    // Respective byte enables are asserted as per write strobes 
                    // Slave register 5
                    slv_reg5[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                  end  
              5'h06:
                for ( byte_index = 0; byte_index <= (AXILITE_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                  if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                    // Respective byte enables are asserted as per write strobes 
                    // Slave register 6
                    slv_reg6[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                  end  
              5'h07:
                for ( byte_index = 0; byte_index <= (AXILITE_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                  if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                    // Respective byte enables are asserted as per write strobes 
                    // Slave register 7
                    slv_reg7[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                  end  
              5'h08:
                for ( byte_index = 0; byte_index <= (AXILITE_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                  if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                    // Respective byte enables are asserted as per write strobes 
                    // Slave register 8
                    slv_reg8[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                  end  
              5'h09:
                for ( byte_index = 0; byte_index <= (AXILITE_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                  if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                    // Respective byte enables are asserted as per write strobes 
                    // Slave register 9
                    slv_reg9[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                  end  
              5'h0A:
                for ( byte_index = 0; byte_index <= (AXILITE_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                  if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                    // Respective byte enables are asserted as per write strobes 
                    // Slave register 10
                    slv_reg10[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                  end  
              5'h0B:
                for ( byte_index = 0; byte_index <= (AXILITE_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                  if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                    // Respective byte enables are asserted as per write strobes 
                    // Slave register 11
                    slv_reg11[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                  end  
              5'h0C:
                for ( byte_index = 0; byte_index <= (AXILITE_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                  if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                    // Respective byte enables are asserted as per write strobes 
                    // Slave register 12
                    slv_reg12[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                  end  
              5'h0D:
                for ( byte_index = 0; byte_index <= (AXILITE_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                  if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                    // Respective byte enables are asserted as per write strobes 
                    // Slave register 13
                    slv_reg13[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                  end  
              5'h0E:
                for ( byte_index = 0; byte_index <= (AXILITE_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                  if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                    // Respective byte enables are asserted as per write strobes 
                    // Slave register 14
                    slv_reg14[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                  end  
              5'h0F:
                for ( byte_index = 0; byte_index <= (AXILITE_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                  if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                    // Respective byte enables are asserted as per write strobes 
                    // Slave register 15
                    slv_reg15[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                  end  
              5'h10:
                for ( byte_index = 0; byte_index <= (AXILITE_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                  if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                    // Respective byte enables are asserted as per write strobes 
                    // Slave register 16
                    slv_reg16[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                  end  
              5'h11:
                for ( byte_index = 0; byte_index <= (AXILITE_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                  if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                    // Respective byte enables are asserted as per write strobes 
                    // Slave register 17
                    slv_reg17[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                  end  
              5'h12:
                for ( byte_index = 0; byte_index <= (AXILITE_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                  if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                    // Respective byte enables are asserted as per write strobes 
                    // Slave register 18
                    slv_reg18[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                  end  
              5'h13:
                for ( byte_index = 0; byte_index <= (AXILITE_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                  if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                    // Respective byte enables are asserted as per write strobes 
                    // Slave register 19
                    slv_reg19[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                  end  
              default : begin
                          axilite_status <= axilite_status;
                          axilite_control <= axilite_control;
                          slv_reg2 <= slv_reg2;
                          slv_reg3 <= slv_reg3;
                          slv_reg4 <= slv_reg4;
                          slv_reg5 <= slv_reg5;
                          slv_reg6 <= slv_reg6;
                          slv_reg7 <= slv_reg7;
                          slv_reg8 <= slv_reg8;
                          slv_reg9 <= slv_reg9;
                          slv_reg10 <= slv_reg10;
                          slv_reg11 <= slv_reg11;
                          slv_reg12 <= slv_reg12;
                          slv_reg13 <= slv_reg13;
                          slv_reg14 <= slv_reg14;
                          slv_reg15 <= slv_reg15;
                          slv_reg16 <= slv_reg16;
                          slv_reg17 <= slv_reg17;
                          slv_reg18 <= slv_reg18;
                          slv_reg19 <= slv_reg19;
                        end
            endcase
          end else begin
            axilite_status <= axilite_status_next;
            axilite_control <= axilite_control_next;
          end
      end
    end    

    // Implement write response logic generation
    // The write response and response valid signals are asserted by the slave 
    // when axi_wready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted.  
    // This marks the acceptance of address and indicates the status of 
    // write transaction.

    always @( posedge S_AXI_ACLK )
    begin
      if ( S_AXI_ARESETN == 1'b0 )
        begin
          axi_bvalid  <= 0;
          axi_bresp   <= 2'b0;
        end 
      else
        begin    
          if (axi_awready && S_AXI_AWVALID && ~axi_bvalid && axi_wready && S_AXI_WVALID)
            begin
              // indicates a valid write response is available
              axi_bvalid <= 1'b1;
              axi_bresp  <= 2'b0; // 'OKAY' response 
            end                   // work error responses in future
          else
            begin
              if (S_AXI_BREADY && axi_bvalid) 
                //check if bready is asserted while bvalid is high) 
                //(there is a possibility that bready is always asserted high)   
                begin
                  axi_bvalid <= 1'b0; 
                end  
            end
        end
    end   

    // Implement axi_arready generation
    // axi_arready is asserted for one S_AXI_ACLK clock cycle when
    // S_AXI_ARVALID is asserted. axi_awready is 
    // de-asserted when reset (active low) is asserted. 
    // The read address is also latched when S_AXI_ARVALID is 
    // asserted. axi_araddr is reset to zero on reset assertion.

    always @( posedge S_AXI_ACLK )
    begin
      if ( S_AXI_ARESETN == 1'b0 )
        begin
          axi_arready <= 1'b0;
          axi_araddr  <= 32'b0;
        end 
      else
        begin    
          if (~axi_arready && S_AXI_ARVALID)
            begin
              // indicates that the slave has acceped the valid read address
              axi_arready <= 1'b1;
              // Read address latching
              axi_araddr  <= S_AXI_ARADDR;
            end
          else
            begin
              axi_arready <= 1'b0;
            end
        end 
    end       

    // Implement axi_arvalid generation
    // axi_rvalid is asserted for one S_AXI_ACLK clock cycle when both 
    // S_AXI_ARVALID and axi_arready are asserted. The slave registers 
    // data are available on the axi_rdata bus at this instance. The 
    // assertion of axi_rvalid marks the validity of read data on the 
    // bus and axi_rresp indicates the status of read transaction.axi_rvalid 
    // is deasserted on reset (active low). axi_rresp and axi_rdata are 
    // cleared to zero on reset (active low).  
    always @( posedge S_AXI_ACLK )
    begin
      if ( S_AXI_ARESETN == 1'b0 )
        begin
          axi_rvalid <= 0;
          axi_rresp  <= 0;
        end 
      else
        begin    
          if (axi_arready && S_AXI_ARVALID && ~axi_rvalid)
            begin
              // Valid read data is available at the read data bus
              axi_rvalid <= 1'b1;
              axi_rresp  <= 2'b0; // 'OKAY' response
            end   
          else if (axi_rvalid && S_AXI_RREADY)
            begin
              // Read data is accepted by the master
              axi_rvalid <= 1'b0;
            end                
        end
    end    

    // Implement memory mapped register select and read logic generation
    // Slave register read enable is asserted when valid address is available
    // and the slave is ready to accept the read address.
    assign slv_reg_rden = axi_arready & S_AXI_ARVALID & ~axi_rvalid;
    always @(*)
    begin
          // Address decoding for reading registers
          case ( axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
            5'h00   : reg_data_out <= axilite_status;
            5'h01   : reg_data_out <= axilite_control;
            5'h02   : reg_data_out <= slv_reg2;
            5'h03   : reg_data_out <= slv_reg3;
            5'h04   : reg_data_out <= slv_reg4;
            5'h05   : reg_data_out <= slv_reg5;
            5'h06   : reg_data_out <= slv_reg6;
            5'h07   : reg_data_out <= slv_reg7;
            5'h08   : reg_data_out <= slv_reg8;
            5'h09   : reg_data_out <= slv_reg9;
            5'h0A   : reg_data_out <= slv_reg10;
            5'h0B   : reg_data_out <= slv_reg11;
            5'h0C   : reg_data_out <= slv_reg12;
            5'h0D   : reg_data_out <= slv_reg13;
            5'h0E   : reg_data_out <= slv_reg14;
            5'h0F   : reg_data_out <= slv_reg15;
            5'h10   : reg_data_out <= slv_reg16;
            5'h11   : reg_data_out <= slv_reg17;
            5'h12   : reg_data_out <= slv_reg18;
            5'h13   : reg_data_out <= slv_reg19;
            default : reg_data_out <= 0;
          endcase
    end

    // Output register or memory read data
    always @( posedge S_AXI_ACLK )
    begin
      if ( S_AXI_ARESETN == 1'b0 )
        begin
          axi_rdata  <= 0;
        end 
      else
        begin    
          // When there is a valid read address (S_AXI_ARVALID) with 
          // acceptance of read address by the slave (axi_arready), 
          // output the read dada 
          if (slv_reg_rden)
            begin
              axi_rdata <= reg_data_out;     // register read data
            end   
        end
    end    
endmodule
