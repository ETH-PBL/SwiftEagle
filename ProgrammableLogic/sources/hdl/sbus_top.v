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
// proprietary S-Bus top module (wraps UART interface and decoder)
//
// UART: 100 kBit/sec baudrate, inverted logic
//       8 data bits, 1 parity bit (even), 2 stop bits
//
// decoder: S-Bus frame consists of 25 bytes. Start byte 0xF0, 22 data bytes, flags
//          byte and end byte 0x00. The 22 data bytes represent 16 channels, i.e.
//          each channel uses 11 bit.
//
// see also: https://digitalwire.ch/de/projekte/futaba-sbus/
//
//////////////////////////////////////////////////////////////////////////////////


module sbus_top #(
    // Width of S_AXI data bus
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    // Width of S_AXI address bus
    parameter integer C_S_AXI_ADDR_WIDTH = 7,
    parameter UART_SAMPLE_TICKS = 1000,
    parameter UART_IDLE_TIME_TICKS = 300000,
    parameter FRAME_TIMEOUT_TICKS = 10000000) (
    input sbus_i,
    output reg sbus_irq,
    output enable_motors_o,
    output stop_motors_o,

    // Global Clock Signal
    input wire  S_AXI_ACLK,
    // Global Reset Signal. This Signal is Active LOW
    input wire  S_AXI_ARESETN,
    // Write address (issued by master, acceped by Slave)
    input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
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
    input wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
    // Write strobes. This signal indicates which byte lanes hold
    // valid data. There is one write strobe bit for each eight
    // bits of the write data bus.    
    input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
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
    input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
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
    output wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
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

    wire [7:0] uart_data;
    wire uart_rdy;
    wire uart_err;

    wire frame_rdy;
    wire frame_timeout;
    wire frame_err;
    reg enable, enable_next;
    reg stop, stop_next;
    reg [31:0] frames_lost, frames_lost_next;
    reg disable_irq, disable_irq_next;

    wire [31:0] channel_1;
    wire [31:0] channel_2;
    wire [31:0] channel_3;
    wire [31:0] channel_4;
    wire [31:0] channel_5;
    wire [31:0] channel_6;
    wire [31:0] channel_7;
    wire [31:0] channel_8;
    wire [31:0] channel_9;
    wire [31:0] channel_10;
    wire [31:0] channel_11;
    wire [31:0] channel_12;
    wire [31:0] channel_13;
    wire [31:0] channel_14;
    wire [31:0] channel_15;
    wire [31:0] channel_16;
    wire [31:0] flags;

    sbus_uart #(
        .SAMPLE_TICKS(UART_SAMPLE_TICKS),
        .IDLE_TIME_TICKS(UART_IDLE_TIME_TICKS))
    sbus_uart_inst (
        .clk_i    ( S_AXI_ACLK    ),
        .rst_ni   ( S_AXI_ARESETN ),
        .sbus_i   ( sbus_i        ),
        .data_o   ( uart_data     ),
        .rdy_o    ( uart_rdy      ),
        .err_o    ( uart_err      )
    );

    sbus_decoder #(
        .FRAME_TIMEOUT_TICKS(FRAME_TIMEOUT_TICKS))
    sbus_decoder_inst (
        .clk_i            ( S_AXI_ACLK        ),
        .rst_ni           ( S_AXI_ARESETN     ),
        .uart_i           ( uart_data         ),
        .rdy_i            ( uart_rdy          ),
        .err_i            ( uart_err          ),
        .channel_1_o      ( channel_1[10:0]   ),
        .channel_2_o      ( channel_2[10:0]   ),
        .channel_3_o      ( channel_3[10:0]   ),
        .channel_4_o      ( channel_4[10:0]   ),
        .channel_5_o      ( channel_5[10:0]   ),
        .channel_6_o      ( channel_6[10:0]   ),
        .channel_7_o      ( channel_7[10:0]   ),
        .channel_8_o      ( channel_8[10:0]   ),
        .channel_9_o      ( channel_9[10:0]   ),
        .channel_10_o     ( channel_10[10:0]  ),
        .channel_11_o     ( channel_11[10:0]  ),
        .channel_12_o     ( channel_12[10:0]  ),
        .channel_13_o     ( channel_13[10:0]  ),
        .channel_14_o     ( channel_14[10:0]  ),
        .channel_15_o     ( channel_15[10:0]  ),
        .channel_16_o     ( channel_16[10:0]  ),
        .flags_o          ( flags[7:0]        ),
        .frame_rdy_o      ( frame_rdy         ),
        .frame_timeout_o  ( frame_timeout     ),
        .frame_err_o      ( frame_err         )
    );

    // Example-specific design signals
    // local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
    // ADDR_LSB is used for addressing 32/64 bit registers/memories
    // ADDR_LSB = 2 for 32 bits (n downto 2)
    // ADDR_LSB = 3 for 64 bits (n downto 3)
    localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH/32) + 1;
    localparam integer OPT_MEM_ADDR_BITS = 4;
    //----------------------------------------------
    //-- Signals for user logic register space example
    //------------------------------------------------
    //-- Number of Slave Registers 22
    reg [C_S_AXI_DATA_WIDTH-1:0] status_ctrl, status_ctrl_next;
    reg [C_S_AXI_DATA_WIDTH-1:0] ch_threshold_low;
    reg [C_S_AXI_DATA_WIDTH-1:0] ch_threshold_high;
    reg [C_S_AXI_DATA_WIDTH-1:0] ch_inactive_value;
    reg [C_S_AXI_DATA_WIDTH-1:0] max_nbr_lost_frames;
    wire slv_reg_rden;
    wire slv_reg_wren;
    reg [C_S_AXI_DATA_WIDTH-1:0] reg_data_out;
    integer byte_index;
    reg aw_en;


    // enable motors / emergency stop
    always @(posedge S_AXI_ACLK, negedge S_AXI_ARESETN) begin
        if (S_AXI_ARESETN == 'b0) begin
            enable <= 1'b0;
            stop <= 1'b0;
            frames_lost <= 32'h00;
            disable_irq <= 1'b0;
        end else begin
            enable <= enable_next;
            stop <= stop_next;
            frames_lost <= frames_lost_next;
            disable_irq <= disable_irq_next;
        end
    end

    always @(*) begin
        enable_next = enable;
        stop_next = stop;
        frames_lost_next = frames_lost;
        status_ctrl_next = status_ctrl;
        disable_irq_next = disable_irq;
        sbus_irq = 1'b0;

        // enable motors as soon as remote control sends valid data with switch SE in middle position
        if (~enable) begin
            if (~frame_err && ~frame_timeout && frame_rdy && ~flags[5] && (channel_5 != ch_inactive_value) && (channel_5 > ch_threshold_low) && (channel_5 < ch_threshold_high)) begin
                enable_next = 1'b1;
                status_ctrl_next[0] = 1'b1;
            end
        end else begin
            // count number of lost frames in a row
            if (frame_rdy) begin
                if (flags[5]) begin
                    frames_lost_next = frames_lost + 1;
                end else begin
                    frames_lost_next = 0;
                end
            end
            // stop motors as soon as there is an frame error, frame timeout, maximum number of lost frames reached, or switch SE triggered
            if (frame_err || frame_timeout || (frames_lost > max_nbr_lost_frames) || (frame_rdy && ((channel_5 != ch_inactive_value) && ((channel_5 <= ch_threshold_low) || (channel_5 >= ch_threshold_high))))) begin
                stop_next = 1'b1;
                status_ctrl_next[0] = 1'b0;
            end
        end

        // interrupt pulse for one clock cycle
        if (~disable_irq && (frame_rdy && ((channel_9 != ch_inactive_value) && (channel_9 >= ch_threshold_high)))) begin
            sbus_irq = 1'b1;
            disable_irq_next = 1'b1;
        end

        // enable interrupt only after acknowledged by user
        if (status_ctrl[1]) begin
            status_ctrl_next[1] = 1'b0;
            disable_irq_next = 1'b0;
        end
    end

    assign enable_motors_o = enable;
    assign stop_motors_o = stop;


    // AXI4LITE signals
    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_awaddr;
    reg axi_awready;
    reg axi_wready;
    reg [1:0] axi_bresp;
    reg axi_bvalid;
    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_araddr;
    reg axi_arready;
    reg [C_S_AXI_DATA_WIDTH-1:0] axi_rdata;
    reg [1:0] axi_rresp;
    reg axi_rvalid;

    // I/O Connections assignments

    assign S_AXI_AWREADY = axi_awready;
    assign S_AXI_WREADY = axi_wready;
    assign S_AXI_BRESP = axi_bresp;
    assign S_AXI_BVALID = axi_bvalid;
    assign S_AXI_ARREADY = axi_arready;
    assign S_AXI_RDATA = axi_rdata;
    assign S_AXI_RRESP = axi_rresp;
    assign S_AXI_RVALID = axi_rvalid;
    // Implement axi_awready generation
    // axi_awready is asserted for one S_AXI_ACLK clock cycle when both
    // S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_awready is
    // de-asserted when reset is low.

    always @( posedge S_AXI_ACLK ) begin
        if ( S_AXI_ARESETN == 1'b0 ) begin
            axi_awready <= 1'b0;
            aw_en <= 1'b1;
        end else begin    
            if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en) begin
                // slave is ready to accept write address when 
                // there is a valid write address and write data
                // on the write address and data bus. This design 
                // expects no outstanding transactions. 
                axi_awready <= 1'b1;
                aw_en <= 1'b0;
            end else if (S_AXI_BREADY && axi_bvalid) begin
                    aw_en <= 1'b1;
                    axi_awready <= 1'b0;
            end else begin
                axi_awready <= 1'b0;
            end
        end
    end       

    // Implement axi_awaddr latching
    // This process is used to latch the address when both 
    // S_AXI_AWVALID and S_AXI_WVALID are valid. 

    always @( posedge S_AXI_ACLK ) begin
        if ( S_AXI_ARESETN == 1'b0 ) begin
            axi_awaddr <= 0;
        end else begin    
            if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en) begin
                // Write Address latching 
                axi_awaddr <= S_AXI_AWADDR;
            end
        end
    end       

    // Implement axi_wready generation
    // axi_wready is asserted for one S_AXI_ACLK clock cycle when both
    // S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_wready is 
    // de-asserted when reset is low. 

    always @( posedge S_AXI_ACLK ) begin
        if ( S_AXI_ARESETN == 1'b0 ) begin
            axi_wready <= 1'b0;
        end else begin    
            if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID && aw_en ) begin
                // slave is ready to accept write data when 
                // there is a valid write address and write data
                // on the write address and data bus. This design 
                // expects no outstanding transactions. 
                axi_wready <= 1'b1;
            end else begin
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

    always @( posedge S_AXI_ACLK ) begin
        if ( S_AXI_ARESETN == 1'b0 ) begin
            status_ctrl <= 0;
            ch_threshold_low <= 300;
            ch_threshold_high <= 1700;
            ch_inactive_value <= 8;
            max_nbr_lost_frames <= 100;
        end else begin
            if (slv_reg_wren) begin
                case ( axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
                    5'h00:
                        for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                        if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                            // Respective byte enables are asserted as per write strobes 
                            // Slave register 0
                            status_ctrl[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                        end  
                    5'h01:
                        for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                        if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                            // Respective byte enables are asserted as per write strobes 
                            // Slave register 1
                            ch_threshold_low[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                        end  
                    5'h02:
                        for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                        if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                            // Respective byte enables are asserted as per write strobes 
                            // Slave register 2
                            ch_threshold_high[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                        end  
                    5'h03:
                        for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                        if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                            // Respective byte enables are asserted as per write strobes 
                            // Slave register 3
                            ch_inactive_value[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                        end  
                    5'h04:
                        for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                        if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                            // Respective byte enables are asserted as per write strobes 
                            // Slave register 4
                            max_nbr_lost_frames[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                        end  
                    default : begin
                        status_ctrl <= status_ctrl;
                        ch_threshold_low <= ch_threshold_low;
                        ch_threshold_high <= ch_threshold_high;
                        ch_inactive_value <= ch_inactive_value;
                        max_nbr_lost_frames <= max_nbr_lost_frames;
                    end
                endcase
            end else begin
                status_ctrl <= status_ctrl_next;
            end
        end
    end    

    // Implement write response logic generation
    // The write response and response valid signals are asserted by the slave 
    // when axi_wready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted.  
    // This marks the acceptance of address and indicates the status of 
    // write transaction.

    always @( posedge S_AXI_ACLK ) begin
        if ( S_AXI_ARESETN == 1'b0 ) begin
            axi_bvalid  <= 0;
            axi_bresp   <= 2'b0;
        end else begin
            if (axi_awready && S_AXI_AWVALID && ~axi_bvalid && axi_wready && S_AXI_WVALID) begin
                // indicates a valid write response is available
                axi_bvalid <= 1'b1;
                axi_bresp  <= 2'b0; // 'OKAY' response 
            end else begin                 // work error responses in future           
                if (S_AXI_BREADY && axi_bvalid) begin
                    //check if bready is asserted while bvalid is high) 
                    //(there is a possibility that bready is always asserted high)   
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

    always @( posedge S_AXI_ACLK ) begin
        if ( S_AXI_ARESETN == 1'b0 ) begin
            axi_arready <= 1'b0;
            axi_araddr  <= 32'b0;
        end else begin    
            if (~axi_arready && S_AXI_ARVALID) begin
                // indicates that the slave has acceped the valid read address
                axi_arready <= 1'b1;
                // Read address latching
                axi_araddr  <= S_AXI_ARADDR;
            end else begin
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
    always @( posedge S_AXI_ACLK ) begin
        if ( S_AXI_ARESETN == 1'b0 ) begin
            axi_rvalid <= 0;
            axi_rresp  <= 0;
        end else begin
            if (axi_arready && S_AXI_ARVALID && ~axi_rvalid) begin
                // Valid read data is available at the read data bus
                axi_rvalid <= 1'b1;
                axi_rresp  <= 2'b0; // 'OKAY' response
            end else if (axi_rvalid && S_AXI_RREADY) begin
                // Read data is accepted by the master
                axi_rvalid <= 1'b0;
            end                
        end
    end    

    // Implement memory mapped register select and read logic generation
    // Slave register read enable is asserted when valid address is available
    // and the slave is ready to accept the read address.
    assign slv_reg_rden = axi_arready & S_AXI_ARVALID & ~axi_rvalid;
    always @(*) begin
        // Address decoding for reading registers
        case ( axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
            5'h00   : reg_data_out <= status_ctrl;
            5'h01   : reg_data_out <= ch_threshold_low;
            5'h02   : reg_data_out <= ch_threshold_high;
            5'h03   : reg_data_out <= ch_inactive_value;
            5'h04   : reg_data_out <= max_nbr_lost_frames;
            5'h05   : reg_data_out <= channel_1;
            5'h06   : reg_data_out <= channel_2;
            5'h07   : reg_data_out <= channel_3;
            5'h08   : reg_data_out <= channel_4;
            5'h09   : reg_data_out <= channel_5;
            5'h0A   : reg_data_out <= channel_6;
            5'h0B   : reg_data_out <= channel_7;
            5'h0C   : reg_data_out <= channel_8;
            5'h0D   : reg_data_out <= channel_9;
            5'h0E   : reg_data_out <= channel_10;
            5'h0F   : reg_data_out <= channel_11;
            5'h10   : reg_data_out <= channel_12;
            5'h11   : reg_data_out <= channel_13;
            5'h12   : reg_data_out <= channel_14;
            5'h13   : reg_data_out <= channel_15;
            5'h14   : reg_data_out <= channel_16;
            5'h15   : reg_data_out <= flags;
            default : reg_data_out <= 0;
        endcase
    end

    // Output register or memory read data
    always @( posedge S_AXI_ACLK ) begin
        if ( S_AXI_ARESETN == 1'b0 ) begin
            axi_rdata  <= 0;
        end else begin    
            // When there is a valid read address (S_AXI_ARVALID) with 
            // acceptance of read address by the slave (axi_arready), 
            // output the read dada 
            if (slv_reg_rden) begin
                axi_rdata <= reg_data_out;     // register read data
            end   
        end
    end   

endmodule
