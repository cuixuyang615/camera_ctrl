//=================================================================
// Name:
//      camera_buffer
// Function:
//      (1)buff the data transmitted from external OV5640 module
//      (2)update relavent control and data register
//      (3)convert data to 28-bit format and send to external 
//         DS90CR287 chip as output cameralink signal
// Revision:
//      (1)writen on 19 April 2022 by cxy
//
//=================================================================

`define PIC2BYTE    1'b1
`define PIC1BYTE    1'b0
module camera_buffer
#(
   parameter BUFF_LENGTH        = 32,
   parameter AXI4_ADDRESS_WIDTH = 32
)
(
   input                        pclk,
   input                        rst_n,
   input                        pic_format,
   input                        vsync,                    //connect to OV5640 port OV_VSYNC
   input                        href,                     //connect to OV5640 port OV_HREF
   input      [7:0]             data_in,                  //connect to OV5640 port OV_D[7:0]
   output reg [BUFF_LENGTH-1:0] data_buffer,              //buffed data from OV5640
   output reg                   buff_done,
   output     [31:0]            data_reg,
   output     [31:0]            data_ctrl,
   output     [27:0]            camlink_data              //28 bits TTL level data, connect to converter chip pin TxIN[27:0]
);
   reg                           cnt;
   reg [15:0]                    pixel;
	 
   reg [11:0]                    col_cnt;
   reg [11:0]                    row_cnt;
	 
   wire                          pixel_done;
   reg                           pic_done;
	
   wire                          data_valid;
   wire                          vaccant;
	 
   reg                           href_half_delay;
   reg [2:0]                     cnt_buffer;
   wire[2:0]                     max_cnt_buffer;
   reg [AXI4_ADDRESS_WIDTH-1:0]  addr_bias;
	 
   reg [BUFF_LENGTH-1:0]         data_temp;////////////reg

   
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
                            (cnt == 1'b0)             ? data_in      :
                                                       pixel[7:0];

            pixel[15:8] <=  (pic_format == `PIC1BYTE) ? 8'd0         :
                            (cnt == 1'b0)             ? pixel[15:8]  :
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
    else//using software processing when not divisible with 4
	cnt_buffer <= 3'd0;//invalid status
    end
	 
    always @(posedge pclk)
    begin
        if((!rst_n)||(vsync))//when a frame has been transmitted, clear the reg
            data_temp <= 32'd0;
        else if(href)
        begin
        case(cnt_buffer)
            3'd1:       data_temp[7:0]   <= data_in;//pixel[7:0];
            3'd2:       data_temp[15:8]  <= data_in;//pixel[7:0];
            3'd3:       data_temp[23:16] <= data_in;//pixel[7:0];
            3'd4:       data_temp[31:24] <= data_in;//pixel[7:0];
	    default:	data_temp	 <= data_temp;
        endcase
        end
	else//keep?/////////////////////////////////////////////////////////////////////////////
	    data_temp <= 32'd0;
    end


endmodule