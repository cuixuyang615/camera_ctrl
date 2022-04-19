//============================================================================
// Name:
//      camera2axi
// Functioin:
//      (1)sending 32-bit buffed data to AXI interconnect, with 2 successive
//         writing(the first one for writing spi addr, the second one for 
//         writing spi data)
// Revision:
//      (1)writen on 3 Mar 2022 by cxy
//
//
//============================================================================

module camera2axi
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
    input                               iclk,
    input                               pclk,
    input                               rst_n,
    input                               vsync,
    input                               buff_done,
    input      [BUFF_LENGTH-1:0]        data_buffer,
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
    //state define
    localparam IDLE         = 2'b00;
    localparam WRITE_ADDR   = 2'b01;
    localparam WRITE_DATA   = 2'b10;
    localparam WRITE_WAIT   = 2'b11;
	 
    wire [31:0] RAM_ADDR;
	 
    reg         axi_send_en;
	 
    wire [31:0] FIFO_data_i;
    wire [31:0] FIFO_data_o;
    wire        FIFO_write_ready;
    wire        FIFO_read_valid;
    reg         rdreq;
    wire        wrreq;
    wire        rdfull,rdempty,wrfull,wrempty;
	 
    reg         pixel_cnt;//=0 -> writing ram addr, =1 -> writing pixel data

    reg  [1:0]  state;
    reg  [1:0]  next_state;

    reg  [AXI4_ADDRESS_WIDTH-1:0] 	addr_bias;

    assign aw_id_o          =   'd4;                		       //set ID to 4
    assign aw_addr_o        =   (pixel_cnt) ? TXFIFO:SPIADR;	       //1:send to TXFIFO, 0:send to SPIADR
    assign aw_len_o         =   8'd0;               		       //1-time/trans per burst
    assign aw_size_o        =   3'b010;             		       //32 bits??
    assign aw_burst_o       =   2'b00;              		       //FIXED burst type
    assign aw_lock_o        =   'd0;                		       //default
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
        else if(FIFO_read_valid)//wrempty				//check if FIFO is empty -> no data to send
            axi_send_en <= 1'b1;
        else if((state==WRITE_WAIT)&&(next_state==IDLE))
            axi_send_en <= 1'b0;
        else
            axi_send_en <= axi_send_en;
    end
	 
    assign FIFO_data_i = data_buffer;
    assign wrreq = buff_done;
   
    spi_slave_dc_fifo 
    #(
      .DATA_WIDTH(AXI4_WDATA_WIDTH),
      .BUFFER_DEPTH(4)
    ) 
    DC_fifo (
	     .clk_a(pclk),
	     .rstn_a(rst_n),
	     .data_a(FIFO_data_i),
	     .valid_a(wrreq),
	     .ready_a(FIFO_write_ready),
	     .clk_b(iclk),
	     .rstn_b(rst_n),
	     .data_b(FIFO_data_o),
	     .valid_b(FIFO_read_valid),
	     .ready_b(rdreq)
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
                        next_state <= WRITE_DATA;//enter wait state if sending data from fifo
                    else
                        next_state <= WRITE_ADDR;
                end
                WRITE_DATA:
                begin
                    if(w_ready_i && w_valid_o)//handshake -> data trans done
		    begin
		       if(pixel_cnt)//second transmission
			 next_state <= FIFO_read_valid ? WRITE_WAIT:WRITE_DATA;
		       else//first transmission
			 next_state <= WRITE_WAIT;
		    end
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
	    rdreq       <= 1'b0;
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
		    rdreq	<= 1'b0;
                end
                WRITE_ADDR:
                begin
                    aw_valid_o  <= 1'b1;    	//update addr
                    w_valid_o   <= 1'b0;    
                    b_ready_o   <= 1'b0;    	//0 or 1?
		    //pixel_cnt	  <= (pixel_cnt) ? 1'b1:1'b0;//latch
		    rdreq	 <= 1'b0;
                end
                WRITE_DATA:
                begin
                    aw_valid_o  <= 1'b0;
                    w_valid_o   <= 1'b1;    //update data
                    b_ready_o   <= 1'b0;    //0 or 1?
		    //pixel_cnt	  <= (pixel_cnt) ? 1'b1:1'b0;
		   rdreq	<= pixel_cnt ? (FIFO_read_valid ? 1'b1:1'b0):1'b0;
                end
                WRITE_WAIT:
                begin
                    aw_valid_o  <= 1'b0;
                    w_valid_o   <= 1'b0;    
                    b_ready_o   <= 1'b1;    //update respond
		    //pixel_cnt	  <= (pixel_cnt)? 1'b0:1'b1;
		    rdreq	<= 1'b0;
                end
            endcase
        end
        else
        begin
            aw_valid_o  <= 1'b0;
            w_valid_o   <= 1'b0;
            b_ready_o   <= 1'b0;
	    //pixel_cnt	<= 1'b0;
	    rdreq	<= 1'b0;
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