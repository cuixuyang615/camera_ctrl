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

`define PIC2BYTE    1'b1
`define PIC1BYTE    1'b0 

module camera_ctrl 
#(
    parameter AXI4_ADDRESS_WIDTH = 32,
    parameter AXI4_RDATA_WIDTH   = 32,
    parameter AXI4_WDATA_WIDTH   = 32,
    parameter AXI4_ID_WIDTH      = 16,
    parameter AXI4_USER_WIDTH    = 10,
	 parameter RAM_BASE		 		= 23'd2047,
	 parameter TXFIFO			 		= 32'h1A102018,
	 parameter SPIADR			 		= 32'h0A10200C
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
    output reg                          aw_valid_o,
    input                               aw_ready_i,
    // ---------------------------------------------------------

    //AXI write data bus -------------- // USED// --------------
    output     [AXI4_WDATA_WIDTH-1:0]   w_data_o,
    output     [AXI4_WDATA_WIDTH/8-1:0] w_strb_o,
    output                              w_last_o,
    output     [AXI4_USER_WIDTH-1:0]    w_user_o,
    output reg                          w_valid_o,
    input                               w_ready_i,
    // ---------------------------------------------------------

    //AXI write response bus -------------- // USED// ----------
    input        [AXI4_ID_WIDTH-1:0]    b_id_i,
    input        [ 1:0]                 b_resp_i,
    input                               b_valid_i,
    input        [AXI4_USER_WIDTH-1:0]  b_user_i,
    output reg                          b_ready_o
    // ---------------------------------------------------------
);
	 //register addr
	 
	 //state define
    localparam IDLE         = 3'b000;
    localparam WRITE_ADDR   = 3'b001;
	 localparam FIFO_WAIT	 = 3'b010;
    localparam WRITE_DATA   = 3'b011;
    localparam WRITE_WAIT   = 3'b100;

	 //internal signals
	 reg cnt;
	 reg [15:0] pixel;
	 
	 reg [11:0] col_cnt;
    reg [11:0] row_cnt;
	 
	 wire pixel_done;
	 reg pic_done;
	 
	 wire data_valid;
    wire vaccant;
	 
	 reg href_half_delay;
	 reg [31:0] data_buffer;
    reg [2:0] cnt_buffer;
	 wire [2:0]max_cnt_buffer;
    reg buff_done;
	 reg [31:0] addr_bias;
	 
	 reg [31:0] data_temp;////////////reg
	 
	 wire [31:0] RAM_ADDR;
	 
	 reg axi_send_en;
	 
	 wire [31:0] FIFO_data_i;
	 wire [31:0] FIFO_data_o;
	 reg rdreq;
	 wire wrreq;
	 wire rdfull,rdempty,wrfull,wrempty;
	 
	 reg pixel_cnt;								//=0 -> writing ram addr, =1 -> writing pixel data

    reg [2:0] state;
    reg [2:0] next_state;

    //pixel reading part
    always@(posedge pclk, negedge rst_n)
    begin
        if(!rst_n)
            cnt <= 1'b0;
        else
        begin
            cnt <=  (pic_format == `PIC1BYTE) ? 1'b0:
                    (cnt == 1'b1)            ? 1'b0:
                                               1'b1;
        end
    end

    assign data_reg = {16'd0,pixel};
    always @(posedge pclk, negedge rst_n)
    begin
        if(!rst_n)
            pixel   <=  16'd0;
        else if(href)
        begin
            pixel[7:0] <=   (pic_format == `PIC1BYTE) ? data_in      :
                            (cnt == 1'b0)            ? data_in      :
                                                       pixel[7:0];

            pixel[15:8] <=  (pic_format == `PIC1BYTE) ? 8'd0         :
                            (cnt == 1'b0)            ? pixel[15:8]  :
                                                       data_in;
        end
        else
            pixel <= pixel;
    end

    //register controlling part 
    always @(posedge pclk, negedge rst_n)
    begin
        if(!rst_n)
            col_cnt <= 12'd0;
        else if(href)
            col_cnt <= col_cnt + 1'b1;
        else
            col_cnt <= 12'd0;
    end

    always @(negedge href, negedge rst_n, posedge vsync)
    begin
        if(!rst_n)
            row_cnt <= 12'd0;
        else if(vsync)
            row_cnt <= 12'd0;
        else if(!href)
            row_cnt <= row_cnt + 1'b1;
        else
            row_cnt <= row_cnt;
    end

    assign pixel_done = (pic_format == `PIC1BYTE) ? 1'b1:cnt;
    assign data_ctrl = {row_cnt, col_cnt, 6'd0, pic_done, pixel_done};

    always @(posedge pclk, negedge rst_n)
    begin
        if(!rst_n)
            pic_done <= 1'b0;
        else if(vsync)
            pic_done <= 1'b1;
        else if(href)
            pic_done <= 1'b0;
        else
            pic_done <= pic_done;
    end

    //cameralink converter control part
    assign data_valid = pixel_done;
    assign vaccant = pic_done;
    assign camlink_data ={vsync, href, data_valid, vaccant, 8'd0, pixel};
	
    //data buffer to FIFO
	 always @(negedge pclk)
	 begin
		  if(!rst_n)
		      buff_done <= 1'b0;
		  else if(cnt_buffer == 3'd4)
				buff_done <= 1'b1;
		  else
				buff_done <= 1'b0;
	 end
	 
	 //half period behind href
	 //external href changes faster than internal cnt etc when clk edging
	 always @(posedge pclk)
	 begin
		  if(!rst_n)
				href_half_delay <= 1'b0;
		  else
		      href_half_delay <= href;
	 end
	 
	 always @(negedge pclk)       //iclk or pclk? negedge for FIFO?
    begin
        if((!rst_n)||(vsync))//when a frame has been transmitted, clear the buffer
				data_buffer <= 32'd0;
		  else if((cnt_buffer == max_cnt_buffer)&&(href_half_delay))
				data_buffer <= data_temp;
		  else
		      data_buffer <= data_buffer;
	 end
	 
	 //counter control, **changes stay with data_temp**
	 //0->initial state, invalid. 1-4->valid loop
	 assign max_cnt_buffer = 3'd4;
	 
	 always @(negedge pclk)
	 begin
        if((!rst_n)||(vsync))//when a frame has been transmitted, clear the counter
				cnt_buffer <= 3'd0;
		  else if(href)//start counter, 1-4->valid loop
		  begin
				if(cnt_buffer == max_cnt_buffer)
					cnt_buffer <= 3'd1;
				else
					cnt_buffer <= cnt_buffer + 3'd1;
		  end
		  else//software processing when not divisible with 4
				cnt_buffer <= 3'd0;//invalid status
	 end
	 
    always @(posedge pclk)
    begin
        if((!rst_n)||(vsync))//when a frame has been transmitted, clear the reg
            data_temp <= 32'd0;
        else if(href)
        begin
            //if((pic_format == `PIC1BYTE))
                case(cnt_buffer)
                    3'd1:       data_temp[7:0]   <= data_in;//pixel[7:0];
                    3'd2:       data_temp[15:8]  <= data_in;//pixel[7:0];
                    3'd3:       data_temp[23:16] <= data_in;//pixel[7:0];
                    3'd4:       data_temp[31:24] <= data_in;//pixel[7:0];
						  default:	  data_temp			 <= data_temp;
                endcase
            /*else
                case(cnt_buffer)
                    3'd1:       data_temp[15:0]  <= pixel;
                    3'd2:       data_temp[31:16] <= pixel;
                    default:    data_temp        <= data_temp;
                endcase
				*/
        end
		  else//keep?/////////////////////////////////////////////////////////////////////////////
		      data_temp <= 32'd0;
    end

    //AXI signal assignment	 
	 //assign RAM_ADDR			 =	  RAM_BASE + addr_bias;				//4 bytes bias per transmit
	 
    assign aw_id_o          =   'd4;                				//set ID to 4
    assign aw_addr_o        =   (pixel_cnt) ? TXFIFO:SPIADR;	//1:send to TXFIFO, 0:send to SPIADR
    assign aw_len_o         =   8'd0;               				//1-time/trans per burst
    assign aw_size_o        =   3'b010;             				//32 bits??
    assign aw_burst_o       =   2'b00;              				//FIXED burst type
    assign aw_lock_o        =   'd0;                				//default
    assign aw_cache_o       =   'd0;
    assign aw_prot_o        =   'd0;
    assign aw_region_o      =   'd0;
    assign aw_user_o        =   'd0;
    assign aw_qos_o         =   'd0;

    assign w_last_o         =   1'b1;
    assign w_strb_o         =   'hF;
    assign w_user_o         =   'd4;
    assign w_data_o         =   (pixel_cnt) ? FIFO_data_o:addr_bias;

    //input external signals
    //b_id_i,
    //b_resp_i,
    //b_valid_i,
    //b_user_i,

    //////////signal controller of AXI bus////////////
	 
	 //sending data from FIFO to AXI bus
    always@(posedge iclk)
    begin
        if(!rst_n)
            axi_send_en <= 1'b0;
        else if(!rdempty)				//check if FIFO is empty -> no data to send
            axi_send_en <= 1'b1;
        else if((state==WRITE_WAIT)&&(next_state==IDLE))
            axi_send_en <= 1'b0;
        else
            axi_send_en <= axi_send_en;
    end
	 
	 assign FIFO_data_i = data_buffer;
	 //setting write signal
	 /*
	 always@(posedge iclk, negedge rst_n)
	 begin
		if(!rst_n)
			wrreq <= 1'b0;
		else if(wrreq)
			wrreq <= 1'b0;
		else if(buff_done)
			wrreq <= 1'b1;
		else
			wrreq <= 1'b0;
	 end*/
	 assign wrreq = buff_done;
	 FIFO CAM_DATA_FIFO(
		.rdclk(iclk),
		.wrclk(pclk),
		.data(FIFO_data_i),
		.rdreq(rdreq),
		.aclr(!rst_n),
		.wrreq(wrreq),
		.rdempty(rdempty),
		.rdfull(rdfull),
		.wrempty(wrempty),
		.wrfull(wrfull),
		.q(FIFO_data_o)
	 );
	 
    always@(posedge iclk)
    begin
        if(!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    always@(state or rst_n or axi_send_en or aw_ready_i or aw_valid_o or w_ready_i or w_valid_o or b_ready_o or b_valid_i or pixel_cnt)
    begin
        if(!rst_n)
            next_state <= IDLE;
        else if(axi_send_en)
        begin
            case(state)
                IDLE:
                begin
                    next_state <= WRITE_ADDR;           //permit to transmit valid 32-bit data
                end
                WRITE_ADDR:
                begin
                    if(aw_ready_i && aw_valid_o)        //handshake -> addr trans done
                        next_state <= (pixel_cnt) ? FIFO_WAIT:WRITE_DATA;//enter wait state if sending data from fifo
                    else
                        next_state <= WRITE_ADDR;
                end
					 FIFO_WAIT:
					 begin
						  next_state <= WRITE_DATA;
					 end
                WRITE_DATA:
                begin
                    if(w_ready_i && w_valid_o)          //handshake -> data trans done
                        next_state <= WRITE_WAIT;
                    else
                        next_state <= WRITE_DATA;
                end
                WRITE_WAIT:
                begin
						  if(pixel_cnt)//sending pixel data
						  begin
								if(b_ready_o && b_valid_i)          //handshake -> respond done
									next_state <= IDLE;
								else
									next_state <= WRITE_WAIT;
						  end
						  else//sending ram addr
						  begin
								if(b_ready_o && b_valid_i)          //handshake -> respond done
									next_state <= WRITE_ADDR;
								else
									next_state <= WRITE_WAIT;
						  end
                end
            endcase
        end
        else
            next_state <= IDLE;                         //stop sending data
    end

    always@(state or rst_n or axi_send_en or pixel_cnt)
    begin
        if(!rst_n)
        begin
            aw_valid_o  <= 1'b0;
            w_valid_o   <= 1'b0;
            b_ready_o   <= 1'b0;
				//pixel_cnt	<= 1'b0;
				rdreq			<= 1'b0;
        end
        else if(axi_send_en)
        begin
            case(state)
                IDLE:
                begin
                    aw_valid_o  <= 1'b0;
                    w_valid_o   <= 1'b0;
                    b_ready_o   <= 1'b0;
						  //pixel_cnt	  <= 1'b0;
						  rdreq		  <= 1'b0;
                end
                WRITE_ADDR:
                begin
                    aw_valid_o  <= 1'b1;    	//update addr
                    w_valid_o   <= 1'b0;    
                    b_ready_o   <= 1'b0;    	//0 or 1?
						  //pixel_cnt	  <= (pixel_cnt) ? 1'b1:1'b0;//latch
						  rdreq		  <= 1'b0;
                end
					 FIFO_WAIT:
					 begin
						  aw_valid_o  <= 1'b0;
                    w_valid_o   <= 1'b0;    //update data
                    b_ready_o   <= 1'b0;    //0 or 1?
						  //pixel_cnt	  <= (pixel_cnt) ? 1'b1:1'b0;
						  rdreq		  <= 1'b1;
					 end
                WRITE_DATA:
                begin
                    aw_valid_o  <= 1'b0;
                    w_valid_o   <= 1'b1;    //update data
                    b_ready_o   <= 1'b0;    //0 or 1?
						  //pixel_cnt	  <= (pixel_cnt) ? 1'b1:1'b0;
						  rdreq		  <= 1'b0;
                end
                WRITE_WAIT:
                begin
                    aw_valid_o  <= 1'b0;
                    w_valid_o   <= 1'b0;    
                    b_ready_o   <= 1'b1;    //update respond
						  //pixel_cnt	  <= (pixel_cnt)? 1'b0:1'b1;
						  rdreq		  <= 1'b0;
                end
            endcase
        end
        else
        begin
            aw_valid_o  <= 1'b0;
            w_valid_o   <= 1'b0;
            b_ready_o   <= 1'b0;
				//pixel_cnt	<= 1'b0;
				rdreq		   <= 1'b0;
        end
    end
	 
	 always @(posedge iclk)
	 begin
		if(!rst_n)
			pixel_cnt <= 1'b0;
		else if((state==WRITE_WAIT))
			pixel_cnt <= ~pixel_cnt;
		else
			pixel_cnt <= pixel_cnt;
	 end

	 
	 always @(posedge iclk)
	 begin
		if((!rst_n)||(vsync))
			addr_bias	<= RAM_BASE;
		else if((state==WRITE_WAIT)&&(next_state==WRITE_ADDR))
			addr_bias	<= addr_bias+32'd4;
		else
			addr_bias	<= addr_bias;
	 end

endmodule