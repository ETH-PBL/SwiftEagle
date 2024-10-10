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
// event recorder
//
//////////////////////////////////////////////////////////////////////////////////

module event_recorder #(
    parameter integer AXILITE_DATA_WIDTH = 32,
    parameter integer AXILITE_ADDR_WIDTH = 5) (

    input clk_i,
    input rst_ni,

    output reg irq,
    output reg err,

    // axi stream slave
    input wire in_axis_aclk,
    input wire in_xis_aresetn,
    output reg in_axis_tready,
    input wire [31:0] in_axis_tdata,
    input wire in_axis_tlast,
    input wire in_axis_tvalid,
    input wire in_axis_tuser,

    // axi stream master
    input wire out_axis_aclk,
    input wire out_axis_aresetn,
    output reg out_axis_tvalid,
    output reg [31:0] out_axis_tdata,
    output reg out_axis_tlast,
    input wire out_axis_tready,

    // data mover cmd interface
    input wire dm_cmd_axis_aclk,
    input wire dm_cmd_axis_aresetn,
    output reg dm_cmd_axis_tvalid,
    output reg [71:0] dm_cmd_axis_tdata,
    input wire dm_cmd_axis_tready,

    // data mover status interface
    input wire dm_sts_axis_aclk,
    input wire dm_sts_axis_aresetn,
    output reg dm_sts_axis_tready,
    input wire [31:0] dm_sts_axis_tdata,
    input wire dm_sts_axis_tlast,
    input wire dm_sts_axis_tvalid,

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

    // magic number indicates 64-bit timestamp
    localparam MAGIC_NUMBER = 32'hCAFE1122;

    //////////////////////////////////////////////////
    //
    // FSM
    // 
    //////////////////////////////////////////////////

    // states
    localparam
        IDLE                        = 4'b0000,
        WAIT_FOR_TLAST              = 4'b0001,
        WAIT_FOR_DATA               = 4'b0010,
        TIMESTAMP_LSB               = 4'b0011,
        TIMESTAMP_MSB               = 4'b0100,
        WAIT_FOR_TRANSFER_COMPLETE  = 4'b0101,
        TIMESTAMP_MAGIC_NOT_READY   = 4'b0110,
        TIMESTAMP_LSB_NOT_READY     = 4'b0111,
        TIMESTAMP_MSB_NOT_READY     = 4'b1000,
        INITIAL_CMD_NOT_READY       = 4'b1001,
        CMD_NOT_READY               = 4'b1010,
        ERROR                       = 4'b1011;
    reg [3:0] state, state_next;

    // assign next state
    always @ (posedge clk_i, negedge rst_ni) begin
        if (rst_ni == 'b0) begin
            state <= IDLE;
        end else begin
            state <= state_next;
        end
    end

    // datamover command
    localparam
        CMD_RSVD    = 4'h0,
        CMD_TAG     = 4'hC,
        CMD_DDR     = 1'b0,         // DRE ReAlignment Request
        CMD_EOF     = 1'b0,         // End of Frame
        CMD_DSA     = 6'h0,         // DRE Stream Alignment (n/a)
        CMD_Type    = 1'b1,         // enables INCR
        CMD_BTT     = 23'hFFFF;     // Bytes to Transfer

    reg [31:0] addr, addr_next;

    reg cmd_tvalid_prev;
    reg [71:0] cmd_tdata_prev;

    reg [31:0] timer, timer_next;

    reg [63:0] timestamp, timestamp_next;

    reg [AXILITE_DATA_WIDTH-1:0] axilite_status, axilite_status_next;
    reg [AXILITE_DATA_WIDTH-1:0] axilite_control, axilite_control_next;
    reg [AXILITE_DATA_WIDTH-1:0] axilite_destination_address, axilite_destination_address_next;
    reg [AXILITE_DATA_WIDTH-1:0] axilite_recording_ticks, axilite_recording_ticks_next;
    reg [AXILITE_DATA_WIDTH-1:0] axilite_bytes_transferred, axilite_bytes_transferred_next;

    // registers reset and update
    always @ (posedge clk_i, negedge rst_ni) begin
        if (rst_ni == 'b0) begin
            addr <= 0;
            cmd_tvalid_prev <= 1'b0;
            cmd_tdata_prev <= 0;
            timer <= 0;
            timestamp <= 0;
        end else begin
            addr <= addr_next;
            cmd_tvalid_prev <= dm_cmd_axis_tvalid;
            cmd_tdata_prev <= dm_cmd_axis_tdata;
            timer <= timer_next;
            timestamp <= timestamp_next;
        end
    end

    // assign next state
    always @(*) begin
        state_next = state;
        in_axis_tready = 1'b0;
        out_axis_tvalid = 1'b0;
        out_axis_tdata = 1'b0;
        out_axis_tlast = 1'b0;
        dm_cmd_axis_tvalid = cmd_tvalid_prev;
        dm_cmd_axis_tdata = cmd_tdata_prev;
        dm_sts_axis_tready = 1'b1;
        addr_next = addr;
        axilite_status_next = axilite_status;
        axilite_control_next = axilite_control;
        axilite_destination_address_next = axilite_destination_address;
        axilite_recording_ticks_next = axilite_recording_ticks;
        axilite_bytes_transferred_next = axilite_bytes_transferred;
        timer_next = timer;
        timestamp_next = timestamp + 1'b1;
        irq = 1'b0;
        err = 1'b0;

        case (state)
            IDLE: begin
                // consume and ignore input stream
                in_axis_tready = 1'b1;
                // wait for start bit
                if (axilite_control[0]) begin
                    axilite_control_next[0] = 1'b0;
                    addr_next = axilite_destination_address;
                    axilite_bytes_transferred_next = 32'h0;
                    timer_next = 0;

                    // send initial start command to datamover
                    dm_cmd_axis_tvalid = 1'b1;
                    dm_cmd_axis_tdata = {CMD_RSVD, CMD_TAG, axilite_destination_address, CMD_DDR,
                                        CMD_EOF, CMD_DSA, CMD_Type, CMD_BTT};  
                    if (~dm_cmd_axis_tready) begin
                        state_next = INITIAL_CMD_NOT_READY;
                    end else begin
                        state_next = WAIT_FOR_TLAST;
                    end
                end
            end
            WAIT_FOR_TLAST: begin
                timer_next = timer + 1;
                in_axis_tready = 1'b1;
                dm_cmd_axis_tvalid = 1'b0;
                // wait for TLAST
                if (in_axis_tlast && in_axis_tvalid) begin
                    state_next = WAIT_FOR_DATA;
                end
            end
            WAIT_FOR_DATA: begin
                timer_next = timer + 1;
                in_axis_tready = 1'b1;
                dm_cmd_axis_tvalid = 1'b0;
                if (in_axis_tvalid) begin
                    // inject magic number that indicates timestamp
                    out_axis_tvalid = 1'b1;
                    out_axis_tdata = MAGIC_NUMBER;
                    out_axis_tlast = 1'b0;
                    // back-pressure
                    in_axis_tready = 1'b0;
                    if (~out_axis_tready) begin
                        state_next = TIMESTAMP_MAGIC_NOT_READY;
                    end else begin
                        state_next = TIMESTAMP_LSB;
                    end
                end
            end
            TIMESTAMP_LSB: begin
                timer_next = timer + 1;
                // inject timestamp (LSB)
                out_axis_tvalid = 1'b1;
                out_axis_tdata = timestamp[31:0];
                out_axis_tlast = 1'b0;
                // back-pressure
                in_axis_tready = 1'b0;
                if (~out_axis_tready) begin
                    state_next = TIMESTAMP_LSB_NOT_READY;
                end else begin
                    state_next = TIMESTAMP_MSB;
                end
            end
            TIMESTAMP_MSB: begin
                timer_next = timer + 1;
                // inject timestamp (MSB)
                out_axis_tvalid = 1'b1;
                out_axis_tdata = timestamp[63:32];
                out_axis_tlast = 1'b0;
                // back-pressure
                in_axis_tready = 1'b0;
                if (~out_axis_tready) begin
                    state_next = TIMESTAMP_MSB_NOT_READY;
                end else begin
                    state_next = WAIT_FOR_TRANSFER_COMPLETE;
                end
            end
            WAIT_FOR_TRANSFER_COMPLETE: begin
                timer_next = timer + 1;
                out_axis_tvalid = in_axis_tvalid;
                out_axis_tdata = in_axis_tdata;
                out_axis_tlast = in_axis_tlast;
                in_axis_tready = out_axis_tready;

                dm_cmd_axis_tvalid = 1'b0;
                // wait for status from datamover
                if (dm_sts_axis_tvalid) begin
                    // check for no error and correct tag
                    if (dm_sts_axis_tdata[7] && (dm_sts_axis_tdata[3:0] == CMD_TAG)) begin
                        addr_next = addr + dm_sts_axis_tdata[30:8];
                        axilite_bytes_transferred_next = axilite_bytes_transferred + dm_sts_axis_tdata[30:8];
                        if (timer > axilite_recording_ticks) begin
                            irq = 1'b1;
                            state_next = IDLE;
                        end else begin
                            // send command to datamover
                            dm_cmd_axis_tvalid = 1'b1;
                            dm_cmd_axis_tdata = {CMD_RSVD, CMD_TAG, addr_next, CMD_DDR,
                                                CMD_EOF, CMD_DSA, CMD_Type, CMD_BTT};  
                            if (~dm_cmd_axis_tready) begin
                                state_next = CMD_NOT_READY;
                            end else begin
                                state_next = WAIT_FOR_DATA;
                            end
                        end
                    end else begin
                        // an error occured
                        state_next = ERROR;
                        axilite_status_next = dm_sts_axis_tdata[7:0];
                    end
                end
            end
            TIMESTAMP_MAGIC_NOT_READY: begin
                timer_next = timer + 1;

                if (out_axis_tready) begin
                    state_next = TIMESTAMP_LSB;
                end
            end
            TIMESTAMP_LSB_NOT_READY: begin
                timer_next = timer + 1;

                if (out_axis_tready) begin
                    state_next = TIMESTAMP_MSB;
                end
            end
            TIMESTAMP_MSB_NOT_READY: begin
                timer_next = timer + 1;

                if (out_axis_tready) begin
                    state_next = WAIT_FOR_TRANSFER_COMPLETE;
                end
            end
            INITIAL_CMD_NOT_READY: begin
                in_axis_tready = 1'b1;

                if (dm_cmd_axis_tready) begin
                    state_next = WAIT_FOR_TLAST;
                end
            end
            CMD_NOT_READY: begin
                timer_next = timer + 1;
                out_axis_tvalid = in_axis_tvalid;
                out_axis_tdata = in_axis_tdata;
                out_axis_tlast = in_axis_tlast;
                in_axis_tready = out_axis_tready;

                if (dm_cmd_axis_tready) begin
                    state_next = WAIT_FOR_TRANSFER_COMPLETE;
                end
            end
            ERROR: begin
                // never leave error state
                err = 1'b1;
            end
            default: begin
                // should never reach here
                err = 1'b1;
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
    localparam integer OPT_MEM_ADDR_BITS = 2;
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
          axilite_destination_address <= 32'h60000000;
          axilite_recording_ticks <= 100000000;
          axilite_bytes_transferred <= 0;
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
                    // Slave register 1
                    axilite_destination_address[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                  end  
              5'h03:
                for ( byte_index = 0; byte_index <= (AXILITE_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                  if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                    // Respective byte enables are asserted as per write strobes 
                    // Slave register 1
                    axilite_recording_ticks[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                  end 
              5'h04:
                for ( byte_index = 0; byte_index <= (AXILITE_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                  if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                    // Respective byte enables are asserted as per write strobes 
                    // Slave register 1
                    axilite_bytes_transferred[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                  end 
              default : begin
                          axilite_status <= axilite_status;
                          axilite_control <= axilite_control;
                          axilite_destination_address <= axilite_destination_address;
                          axilite_recording_ticks <= axilite_recording_ticks;
                          axilite_bytes_transferred <= axilite_bytes_transferred;
                        end
            endcase
          end else begin
            axilite_status <= axilite_status_next;
            axilite_control <= axilite_control_next;
            axilite_destination_address <= axilite_destination_address_next;
            axilite_recording_ticks <= axilite_recording_ticks_next;
            axilite_bytes_transferred <= axilite_bytes_transferred_next;
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
            5'h02   : reg_data_out <= axilite_destination_address;
            5'h03   : reg_data_out <= axilite_recording_ticks;
            5'h04   : reg_data_out <= axilite_bytes_transferred;
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
