
//Original audio codec code taken from
//Howard Mao's FPGA blog
//http://zhehaomao.com/blog/fpga/2014/01/15/sockit-8.html
//MOdified as needed

/* audio_effects.sv
    Reads the audio data from the ROM blocks and sends them to the 
    audio codec interface
*/

module audio_effects (
    input  clk, //audio clock
    input  sample_end, //sample ends
    input  sample_req, //request new sample
	 input [15:0] audio_sample, //get audio sample from audio codec interface, not needed here
    output [15:0] audio_output, //sends audio sample to audio codec
    input [15:0] M_bell,    //bell sound ROM data
    input [15:0] M_city,    //city sound ROM data
    input [15:0] M_who, //whoosh sound ROM data
    input [15:0] M_sw,  //sword sound ROM data
    output [14:0] addr_bell,    //ROM addresses
    output [14:0] addr_city,
    output [15:0] addr_who,
    output [14:0] addr_sw,
    input  [1:0] control    //Control from avalon bus
);


reg  [15:0]  index = 15'd0;     //index through the sound ROM data for different sounds
reg  [15:0]  index_who = 16'd0;
reg  [15:0]  index_bell = 15'd0;
reg  [15:0]  index_sw = 15'd0;
reg [15:0] count1 = 15'd0;
reg [15:0] count2 = 15'd0;

reg [15:0] dat;

assign audio_output = dat;

//assign index to ROM addresses
always @(posedge clk) begin
    
    addr_bell <= index_bell;
    addr_city <= index;
    addr_who <= index_who;
    addr_sw <= index_sw;

end

//Keep playing background (city) sound if control is off
//Play sword sound if control is ON

always @(posedge clk) begin

    if (sample_req) begin
	      if (control == 2'b10&count1==15'd0 ) 
			begin
            if (index_who <= 16'd65534) 
					begin //play sword sound
						dat <= M_who;
						index_who <= index_who +1'b1;
					end
				 if (index_who ==16'd65535)
				   begin
				      dat<=M_city;
					   index<=index+1'b1;
					end
				if (index ==15'd32767)	
					begin
						index <= 15'd0;
						index_who<=16'd0;
						count1<=15'd1;
					end
		 /*   else begin
		        index_bell <= index_bell +1'b1; //increment sword index
                count <= count + 1'b1;
            end*/
			end
		  
        if (control == 2'b01 ) begin
		      count1<=15'd0;
            if (index_sw <= 15'd10000)  //play sword sound
                dat <= M_sw;
		    if (index_sw == 15'd10000) begin
                index_sw <= 15'd10001;
					 dat<=0;
					  end
		    else begin
		        index_sw <= index_sw +1'b1; //increment sword index
              //  count <= count + 1'b1;
            end
        end
		 if (control ==2'b00)
		     index_sw<=15'd0;
		  
 /*     if (control == 2'b00)  
		  begin //play city sound
            index_sw <= 15'b0;
            dat <= M_city;
        end
        
		if (index == 15'd22049)
            index <= 15'd0;
		else
		    index <= index +1'b1;   //increment city index
    */
		end
	   
		else
            dat <= 16'd0;
end

endmodule
