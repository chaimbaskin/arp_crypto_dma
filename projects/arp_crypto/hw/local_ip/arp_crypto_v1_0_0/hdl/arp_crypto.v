//-
// Copyright (c) 2015 University of Cambridge
// Copyright (c) 2015 Noa Zilberman
// All rights reserved.
//
// This software was developed by the University of Cambridge Computer Laboratory 
// under EPSRC INTERNET Project EP/H040536/1, National Science Foundation under Grant No. CNS-0855268,
// and Defense Advanced Research Projects Agency (DARPA) and Air Force Research Laboratory (AFRL), 
// under contract FA8750-11-C-0249.
//
// @NETFPGA_LICENSE_HEADER_START@
//
// Licensed to NetFPGA Open Systems C.I.C. (NetFPGA) under one or more contributor
// license agreements.  See the NOTICE file distributed with this work for
// additional information regarding copyright ownership.  NetFPGA licenses this
// file to you under the NetFPGA Hardware-Software License, Version 1.0 (the
// "License"); you may not use this file except in compliance with the
// License.  You may obtain a copy of the License at:
//
//   http://www.netfpga-cic.org
//
// Unless required by applicable law or agreed to in writing, Work distributed
// under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations under the License.
//
// @NETFPGA_LICENSE_HEADER_END@
//



`include "arp_crypto_cpu_regs_defines.v"

module arp_crypto
#(
    //Master AXI Stream Data Width
    parameter C_M_AXIS_DATA_WIDTH=256,
    parameter C_S_AXIS_DATA_WIDTH=256,
    parameter C_M_AXIS_TUSER_WIDTH=128,
    parameter C_S_AXIS_TUSER_WIDTH=128,
    parameter SRC_PORT_POS=16,
    parameter DST_PORT_POS=24,

 // AXI Registers Data Width
    parameter C_S_AXI_DATA_WIDTH    = 32,          
    parameter C_S_AXI_ADDR_WIDTH    = 12,          
    parameter C_USE_WSTRB           = 0,	   
    parameter C_DPHASE_TIMEOUT      = 0,               
    parameter C_NUM_ADDRESS_RANGES = 1,
    parameter  C_TOTAL_NUM_CE       = 1,
    parameter  C_S_AXI_MIN_SIZE    = 32'h0000_FFFF,
    //parameter [0:32*2*C_NUM_ADDRESS_RANGES-1]   C_ARD_ADDR_RANGE_ARRAY  = 
    //                                             {2*C_NUM_ADDRESS_RANGES
    //                                              {32'h00000000}
    //                                             },
    parameter [0:8*C_NUM_ADDRESS_RANGES-1] C_ARD_NUM_CE_ARRAY  = 
                                                {
                                                 C_NUM_ADDRESS_RANGES{8'd1}
                                                 },
    parameter     C_FAMILY            = "virtex7", 
    parameter C_BASEADDR            = 32'h00000000,
    parameter C_HIGHADDR            = 32'h0000FFFF


)
(
    // Global Ports
    input axis_aclk,
    input axis_resetn,

    // Master Stream Ports (interface to data path)
    output reg [C_M_AXIS_DATA_WIDTH - 1:0] m_axis_tdata,
    output reg [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] m_axis_tkeep,
    output reg [C_M_AXIS_TUSER_WIDTH-1:0] m_axis_tuser,
    output reg m_axis_tvalid,
    input   m_axis_tready,
    output reg m_axis_tlast,

    // Slave Stream Ports (interface to RX queues)
    input [C_S_AXIS_DATA_WIDTH - 1:0] s_axis_tdata,
    input [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_tkeep,
    input [C_S_AXIS_TUSER_WIDTH-1:0] s_axis_tuser,
    input  s_axis_tvalid,
    output s_axis_tready,
    input  s_axis_tlast,

// Slave AXI Ports
    input                                     S_AXI_ACLK,
    input                                     S_AXI_ARESETN,
    input      [C_S_AXI_ADDR_WIDTH-1 : 0]     S_AXI_AWADDR,
    input                                     S_AXI_AWVALID,
    input      [C_S_AXI_DATA_WIDTH-1 : 0]     S_AXI_WDATA,
    input      [C_S_AXI_DATA_WIDTH/8-1 : 0]   S_AXI_WSTRB,
    input                                     S_AXI_WVALID,
    input                                     S_AXI_BREADY,
    input      [C_S_AXI_ADDR_WIDTH-1 : 0]     S_AXI_ARADDR,
    input                                     S_AXI_ARVALID,
    input                                     S_AXI_RREADY,
    output                                    S_AXI_ARREADY,
    output     [C_S_AXI_DATA_WIDTH-1 : 0]     S_AXI_RDATA,
    output     [1 : 0]                        S_AXI_RRESP,
    output                                    S_AXI_RVALID,
    output                                    S_AXI_WREADY,
    output     [1 :0]                         S_AXI_BRESP,
    output                                    S_AXI_BVALID,
    output                                    S_AXI_AWREADY
);

   reg      [`REG_ID_BITS]    id_reg;
   reg      [`REG_VERSION_BITS]    version_reg;
   wire     [`REG_RESET_BITS]    reset_reg;
   reg      [`REG_FLIP_BITS]    ip2cpu_flip_reg;
   wire     [`REG_FLIP_BITS]    cpu2ip_flip_reg;
   reg      [`REG_PKTIN_BITS]    pktin_reg;
   wire                             pktin_reg_clear;
   reg      [`REG_PKTOUT_BITS]    pktout_reg;
   wire                             pktout_reg_clear;
   reg      [`REG_DEBUG_BITS]    ip2cpu_debug_reg;
   wire     [`REG_DEBUG_BITS]    cpu2ip_debug_reg;
   // reg      [`REG_KEY_BITS]    ip2cpu_key_reg;
   // wire     [`REG_KEY_BITS]    cpu2ip_key_reg;

   reg      [`REG_DATA0_BITS]  ip2cpu_data0_reg;
   wire     [`REG_DATA0_BITS]  cpu2ip_data0_reg;
   reg      [`REG_DATA1_BITS]  ip2cpu_data1_reg;
   wire     [`REG_DATA1_BITS]  cpu2ip_data1_reg;
   reg      [`REG_DATA2_BITS]  ip2cpu_data2_reg;
   wire     [`REG_DATA2_BITS]  cpu2ip_data2_reg;
   reg      [`REG_DATA3_BITS]  ip2cpu_data3_reg;
   wire     [`REG_DATA3_BITS]  cpu2ip_data3_reg;

   wire clear_counters;
   wire reset_registers;


   function integer log2;
      input integer number;
      begin
         log2=0;
         while(2**log2<number) begin
            log2=log2+1;
         end
      end
   endfunction // log2
   


   // ---------- Local Parameters ---------
   localparam IDLE              = 6'b000001;
   localparam ARP_1             = 6'b000010;
   localparam ARP_DMA           = 6'b000100;
   localparam DMA_1             = 6'b001000;
   localparam DMA_READ          = 6'b010000; 
   localparam TRANSPERANT       = 6'b100000; 

   localparam MAGIC             = 32'hA5A5A5A5;
   
   localparam DMA_IDENT         = 16'hFF;        //TBD
   localparam TYPE_HIGH         = (6+6)*8 + 2*8 -1  ; //src + dest + type 
   localparam TYPE_LOW          = (6+6)*8   ; //src + dest + type    
   localparam ARP_TYPE          = 16'h608;  

   // ------------- Regs/ wires -----------
   
   reg                              dma_arp_n;
   wire [31:0]                      min_count_data;
   reg  [10:0]                      dma_counter;
   reg  [5:0]                       byte_counter_plus;
   reg  [5:0]                       byte_counter_minus;
   

   
   
   wire                             dma_fifo_empty;
   wire                             dma_fifo_nearly_full;
   reg                              dma_fifo_rd_en;  
   
   wire [C_M_AXIS_TUSER_WIDTH-1:0]  dma_fifo_out_tuser;
   wire [C_M_AXIS_DATA_WIDTH-1:0]   dma_fifo_out_tdata;
   wire [C_M_AXIS_DATA_WIDTH/8-1:0] dma_fifo_out_tkeep;
   wire  	                        dma_fifo_out_tlast;
   
   wire                             fifo_nearly_full;
   wire                             fifo_empty;
   reg                              fifo_rd_en;
   
   wire [C_M_AXIS_TUSER_WIDTH-1:0]  fifo_out_tuser;
   wire [C_M_AXIS_DATA_WIDTH-1:0]   fifo_out_tdata;
   wire [C_M_AXIS_DATA_WIDTH/8-1:0] fifo_out_tkeep;
   wire  	                        fifo_out_tlast;
   
   

   

   reg  [C_M_AXIS_TUSER_WIDTH-1:0]  dma_s_axis_tuser;
   reg  [C_M_AXIS_DATA_WIDTH-1:0]   dma_s_axis_tdata;
   reg  [C_M_AXIS_DATA_WIDTH/8-1:0] dma_s_axis_tkeep;
   reg  	                    dma_s_axis_tlast;
   



   reg  [5:0]                       state, next_state;
   reg  [31:0]                      size,offset;
   reg  [31:0]                      offset_tmp;


   // assign offset    = ip2cpu_data1_reg;
   // assign reg_2     = ip2cpu_data2_reg;
   // assign reg_3     = ip2cpu_data3_reg;


   // ------------ Modules -------------

   fallthrough_small_fifo
   #( .WIDTH(C_M_AXIS_DATA_WIDTH+C_M_AXIS_TUSER_WIDTH+C_M_AXIS_DATA_WIDTH/8+1),
      .MAX_DEPTH_BITS(2)
    )
    input_fifo
    ( // Outputs
      .dout                         ({fifo_out_tlast, fifo_out_tuser, fifo_out_tkeep, fifo_out_tdata}),
      .full                         (),
      .nearly_full                  (fifo_nearly_full),
      .prog_full                    (),
      .empty                        (fifo_empty),
      // Inputs
      .din                          ({s_axis_tlast, s_axis_tuser, s_axis_tkeep, s_axis_tdata}),
      .wr_en                        (s_axis_tvalid & s_axis_tready),
      .rd_en                        (fifo_rd_en),
      .reset                        (~axis_resetn),
      .clk                          (axis_aclk));
      
      
         fallthrough_small_fifo
   #( .WIDTH(C_M_AXIS_DATA_WIDTH+C_M_AXIS_TUSER_WIDTH+C_M_AXIS_DATA_WIDTH/8+1),
      .MAX_DEPTH_BITS(16)
    )
    dma_fifo
    ( // Outputs
      .dout                         ({dma_fifo_out_tlast, dma_fifo_out_tuser, dma_fifo_out_tkeep, dma_fifo_out_tdata}),
      .full                         (),
      .nearly_full                  (dma_fifo_nearly_full),
      .prog_full                    (),
      .empty                        (dma_fifo_empty),
      // Inputs
      .din                          ({dma_s_axis_tlast, dma_s_axis_tuser, dma_s_axis_tkeep, dma_s_axis_tdata}),
      .wr_en                        (dma_arp_n),
      .rd_en                        (dma_fifo_rd_en),
      .reset                        (~axis_resetn),
      .clk                          (axis_aclk));

   // ------------- Logic ------------

   assign s_axis_tready = !fifo_nearly_full;
   assign min_count_data = ((1500 - 64) < (size - offset)) ? (1500 - 64) : (size - offset); 

  /*********************************************************************
   * Wait until the Ethernet header has been decoded and the output
   * port is found, then write the module header and move the packet
   * to the output
   **********************************************************************/
    always @* begin
        m_axis_tuser = fifo_out_tuser;
        m_axis_tdata = fifo_out_tdata;
        m_axis_tkeep = fifo_out_tkeep;
        m_axis_tlast = fifo_out_tlast;
        m_axis_tvalid = 0; 
        fifo_rd_en = 0;
        dma_arp_n = 0;  
        offset_tmp = 0;
        byte_counter_plus = 0;
        byte_counter_minus = 0;       
        next_state = state;                                        
    
        case(state)                                                
            IDLE: begin
                if (!fifo_empty && m_axis_tready) begin                                   
                    fifo_rd_en = 1;                                                         
                    if (fifo_out_tdata[TYPE_HIGH : TYPE_LOW] == ARP_TYPE && min_count_data == dma_counter ) 
                    begin
			m_axis_tvalid = 1;
                        next_state = ARP_1;
                        m_axis_tuser[15:0] = (min_count_data + 64);
                        
                    end
                    else if ( fifo_out_tuser[23:16] == DMA_IDENT)
                    begin   
                        next_state    = DMA_1;
                        m_axis_tuser  = 0;
                        m_axis_tdata  = 0;
                        m_axis_tkeep  = 0;
                        m_axis_tlast  = 0;
                    end
                    else 
                    begin
			m_axis_tvalid = 1;
                        next_state   = TRANSPERANT;
                    end
                end                                                                        
            end
        
            ARP_1: begin                            //ADD METADATA : OFFSET,MAGIC ETC.. 
                m_axis_tvalid = !fifo_empty;
                offset_tmp  =  dma_counter;             
                if (m_axis_tvalid && m_axis_tready) 
                begin                                   
                    fifo_rd_en = 1;  
                    m_axis_tlast = 0;
                    m_axis_tdata[255*8-1 : 22*8]    = 0;
                    m_axis_tdata[22*8-1  : 10*8]    = {size,offset,MAGIC}; 
                    m_axis_tdata[10*8-1  : 0]       = fifo_out_tdata;
                    m_axis_tkeep[31:0]              = {32{1'b1}};
                    next_state = ARP_DMA;
                end
            end
        
    
            ARP_DMA: 
            begin
                m_axis_tvalid = 1; 
                if (m_axis_tvalid && m_axis_tready) 
                begin
                    dma_fifo_rd_en = 1;
                    m_axis_tuser = dma_fifo_out_tuser;
                    m_axis_tdata = dma_fifo_out_tdata;
                    m_axis_tkeep = dma_fifo_out_tkeep;
                    m_axis_tlast = dma_fifo_out_tlast;
                    if (dma_fifo_out_tlast) 
                    begin
                        next_state = IDLE;
                    end
                end	
                byte_counter_minus =    (dma_fifo_out_tkeep == {32{1'b1}}) ? 32:
                                        (dma_fifo_out_tkeep == {31{1'b1}}) ? 31:
                                        (dma_fifo_out_tkeep == {30{1'b1}}) ? 30:
                                        (dma_fifo_out_tkeep == {29{1'b1}}) ? 29:
                                        (dma_fifo_out_tkeep == {28{1'b1}}) ? 28:
                                        (dma_fifo_out_tkeep == {27{1'b1}}) ? 27:
                                        (dma_fifo_out_tkeep == {26{1'b1}}) ? 26:
                                        (dma_fifo_out_tkeep == {25{1'b1}}) ? 25:
                                        (dma_fifo_out_tkeep == {24{1'b1}}) ? 24:
                                        (dma_fifo_out_tkeep == {23{1'b1}}) ? 23:
                                        (dma_fifo_out_tkeep == {22{1'b1}}) ? 22:
                                        (dma_fifo_out_tkeep == {21{1'b1}}) ? 21:
                                        (dma_fifo_out_tkeep == {20{1'b1}}) ? 20:
                                        (dma_fifo_out_tkeep == {19{1'b1}}) ? 19:
                                        (dma_fifo_out_tkeep == {18{1'b1}}) ? 18:
                                        (dma_fifo_out_tkeep == {17{1'b1}}) ? 17:
                                        (dma_fifo_out_tkeep == {16{1'b1}}) ? 16:
                                        (dma_fifo_out_tkeep == {15{1'b1}}) ? 15:
                                        (dma_fifo_out_tkeep == {14{1'b1}}) ? 14:
                                        (dma_fifo_out_tkeep == {13{1'b1}}) ? 13:
                                        (dma_fifo_out_tkeep == {12{1'b1}}) ? 12:
                                        (dma_fifo_out_tkeep == {11{1'b1}}) ? 11:
                                        (dma_fifo_out_tkeep == {10{1'b1}}) ? 10:
                                        (dma_fifo_out_tkeep == {9{1'b1}}) ? 9:
                                        (dma_fifo_out_tkeep == {8{1'b1}}) ? 8:
                                        (dma_fifo_out_tkeep == {7{1'b1}}) ? 7:
                                        (dma_fifo_out_tkeep == {6{1'b1}}) ? 6:
                                        (dma_fifo_out_tkeep == {5{1'b1}}) ? 5:
                                        (dma_fifo_out_tkeep == {4{1'b1}}) ? 4:
                                        (dma_fifo_out_tkeep == {3{1'b1}}) ? 3:
                                        (dma_fifo_out_tkeep == {2{1'b1}}) ? 2:
                                        (dma_fifo_out_tkeep == {1{1'b1}}) ? 1: 
                                                                            0;

            end
            
            DMA_1: 
            begin
                fifo_rd_en = 1;
                m_axis_tuser = 0;
                m_axis_tdata = 0;
                m_axis_tkeep = 0;
                m_axis_tlast = 0;
            end
            
          
            DMA_READ: 
            begin
                dma_arp_n = 1;
                fifo_rd_en = 1; 
                m_axis_tuser = 0;
                m_axis_tdata = 0;
                m_axis_tkeep = 0;
                m_axis_tlast = 0;
                dma_s_axis_tlast = fifo_out_tlast;
                dma_s_axis_tuser = fifo_out_tuser;
                dma_s_axis_tkeep = fifo_out_tkeep;
                dma_s_axis_tdata = fifo_out_tdata;
                if (fifo_out_tlast) 
                begin
                    next_state = IDLE;
                end
                byte_counter_plus =     (fifo_out_tkeep == {32{1'b1}}) ? 32:
                                        (fifo_out_tkeep == {31{1'b1}}) ? 31:
                                        (fifo_out_tkeep == {30{1'b1}}) ? 30:
                                        (fifo_out_tkeep == {29{1'b1}}) ? 29:
                                        (fifo_out_tkeep == {28{1'b1}}) ? 28:
                                        (fifo_out_tkeep == {27{1'b1}}) ? 27:
                                        (fifo_out_tkeep == {26{1'b1}}) ? 26:
                                        (fifo_out_tkeep == {25{1'b1}}) ? 25:
                                        (fifo_out_tkeep == {24{1'b1}}) ? 24:
                                        (fifo_out_tkeep == {23{1'b1}}) ? 23:
                                        (fifo_out_tkeep == {22{1'b1}}) ? 22:
                                        (fifo_out_tkeep == {21{1'b1}}) ? 21:
                                        (fifo_out_tkeep == {20{1'b1}}) ? 20:
                                        (fifo_out_tkeep == {19{1'b1}}) ? 19:
                                        (fifo_out_tkeep == {18{1'b1}}) ? 18:
                                        (fifo_out_tkeep == {17{1'b1}}) ? 17:
                                        (fifo_out_tkeep == {16{1'b1}}) ? 16:
                                        (fifo_out_tkeep == {15{1'b1}}) ? 15:
                                        (fifo_out_tkeep == {14{1'b1}}) ? 14:
                                        (fifo_out_tkeep == {13{1'b1}}) ? 13:
                                        (fifo_out_tkeep == {12{1'b1}}) ? 12:
                                        (fifo_out_tkeep == {11{1'b1}}) ? 11:
                                        (fifo_out_tkeep == {10{1'b1}}) ? 10:
                                        (fifo_out_tkeep == {9{1'b1}}) ? 9:
                                        (fifo_out_tkeep == {8{1'b1}}) ? 8:
                                        (fifo_out_tkeep == {7{1'b1}}) ? 7:
                                        (fifo_out_tkeep == {6{1'b1}}) ? 6:
                                        (fifo_out_tkeep == {5{1'b1}}) ? 5:
                                        (fifo_out_tkeep == {4{1'b1}}) ? 4:
                                        (fifo_out_tkeep == {3{1'b1}}) ? 3:
                                        (fifo_out_tkeep == {2{1'b1}}) ? 2:
                                        (fifo_out_tkeep == {1{1'b1}}) ? 1: 
                                                                        0;
            end 
            
            TRANSPERANT: begin
                if (fifo_out_tlast) 
                begin
                    next_state = IDLE;
                end
            end   
            
        endcase 
   end

    always @(posedge axis_aclk) begin
        if (~axis_resetn) begin
            state <= IDLE;
        end
        else begin
            state <= next_state;
        end
    end
    
    
    always @(posedge axis_aclk) begin
        if (~axis_resetn) begin
            dma_counter <= 0;
            size        <= 0;
            offset      <= 0;
        end
        else begin
            size        <= ip2cpu_data0_reg;
            dma_counter <= dma_counter + byte_counter_plus - byte_counter_minus; 
            if (size != ip2cpu_data0_reg || size == offset) begin
                offset      <= 0;
            end    
            else begin
                offset      <= offset + offset_tmp;
            end
        end
    end
    
    


//Registers section
arp_crypto_cpu_regs 
 #(
   .C_BASE_ADDRESS        (C_BASEADDR),
   .C_S_AXI_DATA_WIDTH (C_S_AXI_DATA_WIDTH),
   .C_S_AXI_ADDR_WIDTH (C_S_AXI_ADDR_WIDTH)
) arp_crypto_cpu_regs_inst
 (   
   // General ports
    .clk                    (axis_aclk),
    .resetn                 (axis_resetn),
   // AXI Lite ports
    .S_AXI_ACLK             (S_AXI_ACLK),
    .S_AXI_ARESETN          (S_AXI_ARESETN),
    .S_AXI_AWADDR           (S_AXI_AWADDR),
    .S_AXI_AWVALID          (S_AXI_AWVALID),
    .S_AXI_WDATA            (S_AXI_WDATA),
    .S_AXI_WSTRB            (S_AXI_WSTRB),
    .S_AXI_WVALID           (S_AXI_WVALID),
    .S_AXI_BREADY           (S_AXI_BREADY),
    .S_AXI_ARADDR           (S_AXI_ARADDR),
    .S_AXI_ARVALID          (S_AXI_ARVALID),
    .S_AXI_RREADY           (S_AXI_RREADY),
    .S_AXI_ARREADY          (S_AXI_ARREADY),
    .S_AXI_RDATA            (S_AXI_RDATA),
    .S_AXI_RRESP            (S_AXI_RRESP),
    .S_AXI_RVALID           (S_AXI_RVALID),
    .S_AXI_WREADY           (S_AXI_WREADY),
    .S_AXI_BRESP            (S_AXI_BRESP),
    .S_AXI_BVALID           (S_AXI_BVALID),
    .S_AXI_AWREADY          (S_AXI_AWREADY),

   
   // Register ports
   .id_reg          (id_reg),
   .version_reg          (version_reg),
   .reset_reg          (reset_reg),
   .ip2cpu_flip_reg          (ip2cpu_flip_reg),
   .cpu2ip_flip_reg          (cpu2ip_flip_reg),
   .pktin_reg          (pktin_reg),
   .pktin_reg_clear    (pktin_reg_clear),
   .pktout_reg          (pktout_reg),
   .pktout_reg_clear    (pktout_reg_clear),
   .ip2cpu_debug_reg          (ip2cpu_debug_reg),
   .cpu2ip_debug_reg          (cpu2ip_debug_reg),
   // .ip2cpu_key_reg          (ip2cpu_key_reg),
   // .cpu2ip_key_reg          (cpu2ip_key_reg),
   .ip2cpu_data0_reg        (ip2cpu_data0_reg),
   .cpu2ip_data0_reg        (cpu2ip_data0_reg),
   .ip2cpu_data1_reg        (ip2cpu_data1_reg),
   .cpu2ip_data1_reg        (cpu2ip_data1_reg),
   .ip2cpu_data2_reg        (ip2cpu_data2_reg),
   .cpu2ip_data2_reg        (cpu2ip_data2_reg),
   .ip2cpu_data3_reg        (ip2cpu_data3_reg),
   .cpu2ip_data3_reg        (cpu2ip_data3_reg),
   
   
   
   
   // Global Registers - user can select if to use
   .cpu_resetn_soft(),//software reset, after cpu module
   .resetn_soft    (),//software reset to cpu module (from central reset management)
   .resetn_sync    (resetn_sync)//synchronized reset, use for better timing
);

   assign clear_counters = reset_reg[0];
   assign reset_registers = reset_reg[4];

   wire [31:0] reg_key_default_little;
   assign reg_key_default_little = `REG_DATA0_DEFAULT;
////registers logic, current logic is just a placeholder for initial compil, required to be changed by the user
always @(posedge axis_aclk)
	if (~resetn_sync | reset_registers) begin
		id_reg <= #1    `REG_ID_DEFAULT;
		version_reg <= #1    `REG_VERSION_DEFAULT;
		ip2cpu_flip_reg <= #1    `REG_FLIP_DEFAULT;
		pktin_reg <= #1    `REG_PKTIN_DEFAULT;
		pktout_reg <= #1    `REG_PKTOUT_DEFAULT;
		ip2cpu_debug_reg <= #1    `REG_DEBUG_DEFAULT;
                // ip2cpu_key_reg <= #1 {reg_key_default_little[7:0],reg_key_default_little[15:8],reg_key_default_little[23:16],reg_key_default_little[31:24]};
                ip2cpu_data0_reg <= #1 {reg_key_default_little[7:0],reg_key_default_little[15:8],reg_key_default_little[23:16],reg_key_default_little[31:24]};
                ip2cpu_data1_reg  <= #1 {reg_key_default_little[7:0],reg_key_default_little[15:8],reg_key_default_little[23:16],reg_key_default_little[31:24]};
                ip2cpu_data2_reg  <= #1 {reg_key_default_little[7:0],reg_key_default_little[15:8],reg_key_default_little[23:16],reg_key_default_little[31:24]};
                ip2cpu_data3_reg  <= #1 {reg_key_default_little[7:0],reg_key_default_little[15:8],reg_key_default_little[23:16],reg_key_default_little[31:24]};
    end
	else begin
		id_reg <= #1    `REG_ID_DEFAULT;
		version_reg <= #1    `REG_VERSION_DEFAULT;
		ip2cpu_flip_reg <= #1    ~cpu2ip_flip_reg;
		pktin_reg[`REG_PKTIN_WIDTH -2: 0] <= #1  clear_counters | pktin_reg_clear ? 'h0  : pktin_reg[`REG_PKTIN_WIDTH-2:0] + (s_axis_tlast && s_axis_tvalid && s_axis_tready) ;
                pktin_reg[`REG_PKTIN_WIDTH-1] <= #1 clear_counters | pktin_reg_clear ? 1'h0  : pktin_reg[`REG_PKTIN_WIDTH-2:0] + (s_axis_tlast && s_axis_tvalid && s_axis_tready) 
                                                     > {(`REG_PKTIN_WIDTH-1){1'b1}} ? 1'b1 : pktin_reg[`REG_PKTIN_WIDTH-1];
                                                               
		pktout_reg [`REG_PKTOUT_WIDTH-2:0]<= #1  clear_counters | pktout_reg_clear ? 'h0  : pktout_reg [`REG_PKTOUT_WIDTH-2:0] + (m_axis_tlast && m_axis_tvalid && m_axis_tready) ;
                pktout_reg [`REG_PKTOUT_WIDTH-1]<= #1  clear_counters | pktout_reg_clear ? 'h0  : pktout_reg [`REG_PKTOUT_WIDTH-2:0] + + (m_axis_tlast && m_axis_tvalid && m_axis_tready)  > {(`REG_PKTOUT_WIDTH-1){1'b1}} ?
                                                                1'b1 : pktout_reg [`REG_PKTOUT_WIDTH-1];
		ip2cpu_debug_reg <= #1    `REG_DEBUG_DEFAULT+cpu2ip_debug_reg;
		// ip2cpu_key_reg <= #1    cpu2ip_key_reg;
        ip2cpu_data0_reg    <= #1 cpu2ip_data0_reg;
        ip2cpu_data1_reg    <= #1 cpu2ip_data1_reg;
        ip2cpu_data2_reg    <= #1 cpu2ip_data2_reg;
        ip2cpu_data3_reg    <= #1 cpu2ip_data3_reg;
        
        end





endmodule // arp_crypto
