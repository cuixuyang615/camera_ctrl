`timescale 1ns/1ns
`define PCLK_PERIOD 80
module camera_ctrl_tb();

	 parameter AXI4_ADDRESS_WIDTH = 32;
    parameter AXI4_RDATA_WIDTH   = 32;
    parameter AXI4_WDATA_WIDTH   = 32;
    parameter AXI4_ID_WIDTH      = 16;
    parameter AXI4_USER_WIDTH    = 10;

	reg iclk,pclk,rst_n;
	
	//integer fp;
	
	wire pic_format;
	assign pic_format = 1'b0;
	
   reg             vsync;                    //connect to OV5640 port OV_VSYNC
   reg             href;                     //connect to OV5640 port OV_HREF
   reg       [7:0] data_in;                  //connect to OV5640 port OV_D[7:0]
   wire     [31:0] data_reg;                 //camera data reg[31:0]
   wire     [31:0] data_ctrl;                //camera data control reg[31:0]
   wire     [27:0] camlink_data;

	wire [AXI4_ID_WIDTH-1:0]      aw_id_o;
   wire [AXI4_ADDRESS_WIDTH-1:0] aw_addr_o;
   wire [ 7:0]                   aw_len_o;
   wire [ 2:0]                   aw_size_o;
   wire [ 1:0]                   aw_burst_o;
   wire                          aw_lock_o;
   wire [ 3:0]                   aw_cache_o;
   wire [ 2:0]                   aw_prot_o;
   wire [ 3:0]                   aw_region_o;
   wire [AXI4_USER_WIDTH-1:0]    aw_user_o;
   wire [ 3:0]                   aw_qos_o;
   wire 									aw_valid_o;
   reg 									aw_ready_i;
    // ---------------------------------------------------------

    //AXI write data bus -------------- // USED// --------------
    wire [AXI4_WDATA_WIDTH-1:0]   w_data_o;
    wire [AXI4_WDATA_WIDTH/8-1:0] w_strb_o;
    wire                          w_last_o;
    wire [AXI4_USER_WIDTH-1:0]    w_user_o;
    wire 								 w_valid_o;
    reg 									 w_ready_i;
    // ---------------------------------------------------------

    //AXI write response bus -------------- // USED// ----------
    wire [AXI4_ID_WIDTH-1:0]    b_id_i;
    wire [ 1:0]                 b_resp_i;
    reg                         b_valid_i;
    wire [AXI4_USER_WIDTH-1:0]  b_user_i;
    wire 							  b_ready_o;

   ///////////newly added/////////////
   initial
   begin
      $fsdbDumpfile("pulpino.fsdb");
      $fsdbDumpvars("+all");
      $fsdbDumpon();
   end
   ///////////////////////////////////
   
	initial
	begin
		iclk = 1'b0;
		forever #10 iclk = ~iclk;//50MHz
	end
	
	initial
	begin
		pclk = 1'b0;
		forever #(`PCLK_PERIOD/2) pclk = ~pclk;
	end

	initial
	begin
		rst_n = 1'b0;
		//fp=$fopen("D:\axi_output.txt","w");
		#100
		rst_n = 1'b1;
		//$fclose(fp);
	end
	
	initial
	begin
		vsync 	= 1'b0;
		href		= 1'b0;
		data_in	= 8'd0;
		#(2*`PCLK_PERIOD)
		
		href		= 1'b1;
		data_in  = 8'h1;
		#(`PCLK_PERIOD)
		data_in  = 8'h2;
		#(`PCLK_PERIOD)
		data_in  = 8'h3;
		#(`PCLK_PERIOD)
		data_in  = 8'h4;
		#(`PCLK_PERIOD)
		data_in	= 8'h0;
		href		= 1'b0;
		
		#(2*`PCLK_PERIOD)
		href		= 1'b1;
		data_in  = 8'h3;
		#(`PCLK_PERIOD)
		data_in  = 8'h4;
		#(`PCLK_PERIOD)
		data_in  = 8'h5;
		#(`PCLK_PERIOD)
		data_in  = 8'h6;
		#(`PCLK_PERIOD)
		data_in	= 8'h0;
		href		= 1'b0;
		
		#(2*`PCLK_PERIOD)
		href		= 1'b1;
		data_in  = 8'h5;
		#(`PCLK_PERIOD)
		data_in  = 8'h6;
		#(`PCLK_PERIOD)
		data_in  = 8'h7;
		#(`PCLK_PERIOD)
		data_in  = 8'h8;
		#(`PCLK_PERIOD)
		data_in	= 8'h0;
		href		= 1'b0;
		
		#(10*`PCLK_PERIOD)
		vsync		= 1'b1;
		#(2*`PCLK_PERIOD)
		vsync		= 1'b0;
		#(`PCLK_PERIOD)
		$stop;
		
	end
	
	always @(posedge iclk or negedge rst_n)
	begin
		if(!rst_n)
			aw_ready_i 	<= 1'b0;
		else if(aw_ready_i && aw_valid_o)
		begin
			aw_ready_i 	<= 1'b0;
			$display("0x%x:",aw_addr_o);
		end
		else
			aw_ready_i 	<= 1'b1;
	end
	
	always @(posedge iclk or negedge rst_n)
	begin
		if(!rst_n)
			w_ready_i 	<= 1'b0;
		else if(w_ready_i && w_valid_o)
		begin
			w_ready_i 	<= 1'b0;
			$display("%x\n",w_data_o);
		end
		else
			w_ready_i 	<= 1'b1;
	end
	
	always @(posedge iclk or negedge rst_n)
	begin
		if(!rst_n)
			b_valid_i	<= 1'b0;
		else if(b_valid_i && b_ready_o)
			b_valid_i 	<= 1'b0;
		else
			b_valid_i 	<= 1'b1;
	end
	
	 assign b_id_i 	= aw_id_o;
    assign b_resp_i 	= 2'd0;	//okey
    //b_valid_i,
    assign b_user_i 	= w_user_o;
	
	
camera_ctrl testblock0
(
    .iclk(iclk),                     			//main clk from chip
    .pclk(pclk),                     			//connect to OV5640 port OV_PCLK
    .rst_n(rst_n),                    			//reset signal
    .pic_format(pic_format),               	//photo format: set 1 for 2-byte/pixel, 0 for 1-byte/pixel
    .vsync(vsync),                    			//connect to OV5640 port OV_VSYNC
    .href(href),                     			//connect to OV5640 port OV_HREF
    .data_in(data_in),                  		//connect to OV5640 port OV_D[7:0]
    .data_reg(data_reg),                 		//camera data reg[31:0]
    .data_ctrl(data_ctrl),                	//camera data control reg[31:0]
    .camlink_data(camlink_data),             //28 bits TTL level data, connect to converter chip pin TxIN[27:0]

    // ---------------------------------------------------------
    // AXI TARG Port Declarations ------------------------------
    //ACLK
    // ---------------------------------------------------------
    //AXI write address bus -------------- // USED// -----------
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
    // ---------------------------------------------------------

    //AXI write data bus -------------- // USED// --------------
    .w_data_o(w_data_o),
    .w_strb_o(w_strb_o),
    .w_last_o(w_last_o),
    .w_user_o(w_user_o),
    .w_valid_o(w_valid_o),
    .w_ready_i(w_ready_i),
    // ---------------------------------------------------------

    //AXI write response bus -------------- // USED// ----------
    .b_id_i(b_id_i),
    .b_resp_i(b_resp_i),
    .b_valid_i(b_valid_i),
    .b_user_i(b_user_i),
    .b_ready_o(b_ready_o)
    // ---------------------------------------------------------
);


endmodule