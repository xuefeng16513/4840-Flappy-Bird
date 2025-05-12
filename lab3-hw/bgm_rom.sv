module bgm_rom (
    input wire clock,
    input wire [14:0] address,  // 15位地址线，可存储32768个采样点
    output reg [15:0] q         // 16位音频数据输出
);

    // 声明ROM
    reg [15:0] rom [0:32767];  // 16位宽，32768深度的ROM
    
    // 在初始化块中加载数据
    initial begin
        $readmemh("bgm.hex", rom);  // 从HEX文件加载数据
    end
    
    // 读取逻辑
    always @(posedge clock) begin
        q <= rom[address];  // 在时钟上升沿读取数据
    end
    
endmodule