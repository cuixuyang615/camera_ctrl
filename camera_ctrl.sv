//============================================================================
// Name:
//      camera_ctrl
// Functioin:
//      (1)reading pixels transmitted from external OV5640 module 
//      (2)update relavent control and data register
//      (3)convert data to 28-bit format and send to external 
//         DS90CR287 chip as output cameralink signal
// 
// Revision:
//      (1)writen on 3 Mar 2022 by cxy
//
//
//============================================================================

module camera_ctrl 
#(
    parameter AXI4_ADDRESS_WIDTH = 32,
    parameter AXI4_RDATA_WIDTH   = 32,
    parameter AXI4_WDATA_WIDTH   = 32,
    parameter AXI4_ID_WIDTH      = 16,
    parameter AXI4_USER_WIDTH    = 10,
    parameter BUFF_LENGTH        = 32,
    parameter RAM_BASE	    	 = 23'd2047,
    parameter TXFIFO		 = 32'h1A102018,
    parameter SPIADR		 = 32'h0A10200C
)
(
    input             iclk,                     //main clk from chip
    input             pclk,                     //connect to OV5640 port OV_PCLK
    input             rst_n,                    //reset signal
    input             pic_format,               //photo format: set 1 for 2-byte/pixel, 0 for 1-byte/pixel
    input             vsync,                    //connect to OV5640 port OV_VSYNC
    input             href,                     //connect to OV5640 port OV_HREF
    input       [7:0] data_in,                  //connect to OV5640 port OV_D[7:0]
    output     [31:0] data_reg,                 //camera data reg[31:0]
    output     [31:0] data_ctrl,                //camera data control reg[31:0]
    output     [27:0] camlink_data,             //28 bits TTL level data, connect to converter chip pin TxIN[27:0]

    // ---------------------------------------------------------
    // AXI TARG Port Declarations ------------------------------
    //ACLK
    // ---------------------------------------------------------
    //AXI write address bus -------------- // USED// -----------
    output     [AXI4_ID_WIDTH-1:0]      aw_id_o,
    output     [AXI4_ADDRESS_WIDTH-1:0] aw_addr_o,
    output     [ 7:0]                   aw_len_o,
    output     [ 2:0]                   aw_size_o,
    output     [ 1:0]                   aw_burst_o,
    output                              aw_lock_o,
    output     [ 3:0]                   aw_cache_o,
    output     [ 2:0]                   aw_prot_o,
    output     [ 3:0]                   aw_region_o,
    output     [AXI4_USER_WIDTH-1:0]    aw_user_o,
    output     [ 3:0]                   aw_qos_o,
    output                              aw_valid_o,
    input                               aw_ready_i,
    // ---------------------------------------------------------

    //AXI write data bus -------------- // USED// --------------
    output     [AXI4_WDATA_WIDTH-1:0]   w_data_o,
    output     [AXI4_WDATA_WIDTH/8-1:0] w_strb_o,
    output                              w_last_o,
    output     [AXI4_USER_WIDTH-1:0]    w_user_o,
    output                              w_valid_o,
    input                               w_ready_i,
    // ---------------------------------------------------------

    //AXI write response bus -------------- // USED// ----------
    input        [AXI4_ID_WIDTH-1:0]    b_id_i,
    input        [ 1:0]                 b_resp_i,
    input                               b_valid_i,
    input        [AXI4_USER_WIDTH-1:0]  b_user_i,
    output                              b_ready_o
    // ---------------------------------------------------------
);
    wire 		   buff_done;
    wire [BUFF_LENGTH-1:0] data_buffer;              //buffed data from OV5640
   
    camera_buffer 
    #(
      .BUFF_LENGTH(BUFF_LENGTH),
      .AXI4_ADDRESS_WIDTH(AXI4_ADDRESS_WIDTH)
    )
    buffer(
	   .pclk(pclk),
	   .rst_n(rst_n),
	   .pic_format(pic_format),
	   .vsync(vsync),
	   .href(href),
	   .data_in(data_in),
	   .data_buffer(data_buffer),
	   .buff_done(buff_done),
	   .data_reg(data_reg),
	   .data_ctrl(data_ctrl),
	   .camlink_data(camlink_data)
	   );

   
    camera2axi
    #(
      .AXI4_ADDRESS_WIDTH(AXI4_ADDRESS_WIDTH),
      .AXI4_RDATA_WIDTH(AXI4_RDATA_WIDTH),
      .AXI4_WDATA_WIDTH(AXI4_WDATA_WIDTH),
      .AXI4_ID_WIDTH(AXI4_ID_WIDTH),
      .AXI4_USER_WIDTH(AXI4_USER_WIDTH),
      .BUFF_LENGTH(BUFF_LENGTH),
      .RAM_BASE(RAM_BASE),
      .TXFIFO(TXFIFO),
      .SPIADR(SPIADR)
    )
    axi_converter(
		  .iclk(iclk),
		  .pclk(pclk),
		  .rst_n(rst_n),
		  .vsync(vsync),
		  .buff_done(buff_done),
		  .data_buffer(data_buffer),
		  .aw_id_o(aw_id_o),
                  .aw_addr_o(aw_addr_o),
		  .aw_len_o(aw_len_o),
		  .aw_size_o(aw_size_o),
		  .aw_burst_o(aw_burst_o),
		  .aw_lock_o(aw_lock_o),
		  .aw_cache_o(aw_cache_o),
		  .aw_prot_o(aw_prot_o),
		  .aw_region_o(aw_region_o),
		  .aw_user_o(aw_user_o),
		  .aw_qos_o(aw_qos_o),
		  .aw_valid_o(aw_valid_o),
		  .aw_ready_i(aw_ready_i),
		  .w_data_o(w_data_o),
		  .w_strb_o(w_strb_o),
		  .w_last_o(w_last_o),
		  .w_user_o(w_user_o),
		  .w_valid_o(w_valid_o),
		  .w_ready_i(w_ready_i),
		  .b_id_i(b_id_i),
		  .b_resp_i(b_resp_i),
		  .b_valid_i(b_valid_i),
		  .b_user_i(b_user_i),
		  .b_ready_o(b_ready_o)
		  );	  

endmodule