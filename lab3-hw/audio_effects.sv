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
    input [15:0] M_bgm, //背景音乐数据
    output [14:0] addr_bell,    //ROM addresses
    output [14:0] addr_city,
    output [15:0] addr_who,
    output [14:0] addr_sw,
    output [14:0] addr_bgm,    //背景音乐地址
    input  [1:0] control    //Control from avalon bus
);


reg  [15:0]  index = 15'd0;     //index through the sound ROM data for different sounds
reg  [15:0]  index_who = 16'd0;
reg  [15:0]  index_bell = 15'd0;
reg  [15:0]  index_sw = 15'd0;
reg  [14:0]  index_bgm = 15'd0; //背景音乐索引
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
    addr_bgm <= index_bgm; //设置背景音乐地址

end

//Keep playing background (bgm) sound and handle other sound effects when control signals change
always @(posedge clk) begin

    if (sample_req) begin
        // 默认播放背景音乐
        dat <= M_bgm;
        
        // 更新背景音乐索引 (循环播放)
        if (index_bgm == 15'd32767) // 根据实际音频长度调整
            index_bgm <= 15'd0;
        else
            index_bgm <= index_bgm + 1'b1;
            
        // 如果有其他控制信号，可以切换到其他音效
        if (control == 2'b10 && count1 == 15'd0) begin
            if (index_who <= 16'd65534) begin
                dat <= M_who;
                index_who <= index_who + 1'b1;
            end
            if (index_who == 16'd65535) begin
                dat <= M_city;
                index <= index + 1'b1;
            end
            if (index == 15'd32767) begin
                index <= 15'd0;
                index_who <= 16'd0;
                count1 <= 15'd1;
            end
        end
          
        if (control == 2'b01) begin
            count1 <= 15'd0;
            if (index_sw <= 15'd10000)  //play sword sound
                dat <= M_sw;
            if (index_sw == 15'd10000) begin
                index_sw <= 15'd10001;
                dat <= 0;
            end
            else begin
                index_sw <= index_sw + 1'b1; //increment sword index
            end
        end
        if (control == 2'b00)
            index_sw <= 15'd0;
    end
    else
        dat <= 16'd0;
end

endmodule