from PIL import Image
import numpy as np

def image_to_mif(image_path, output_file, width=640, height=480, format='B3G3R2'):
    # 打开图像并调整大小
    img = Image.open(image_path)
    img = img.resize((width, height))
    
    # 将图像转换为RGB模式
    if img.mode != 'RGB':
        img = img.convert('RGB')
    
    # 获取像素数据
    pixels = np.array(img)
    
    # 开始写入MIF文件
    with open(output_file, 'w') as f:
        # 写入MIF文件头
        f.write("-- Memory Initialization File for Flappy Bird Start Screen\n")
        f.write("WIDTH=8;\n")  # 8位宽（一个像素一个字节）
        f.write(f"DEPTH={width * height};\n")  # 深度为总像素数
        f.write("ADDRESS_RADIX=HEX;\n")  # 十六进制地址
        f.write("DATA_RADIX=HEX;\n\n")  # 十六进制数据
        f.write("CONTENT BEGIN\n")
        
        # 写入像素数据
        pixel_count = 0
        for y in range(height):
            for x in range(width):
                r, g, b = pixels[y, x]
                
                if format == 'B3G3R2':
                    # 转换为B3G3R2格式（8位）
                    b_val = (b >> 5) & 0x7
                    g_val = (g >> 5) & 0x7
                    r_val = (r >> 6) & 0x3
                    color = (b_val << 5) | (g_val << 2) | r_val
                elif format == 'R3G3B2':
                    # 转换为R3G3B2格式（8位）
                    r_val = (r >> 5) & 0x7
                    g_val = (g >> 5) & 0x7
                    b_val = (b >> 6) & 0x3
                    color = (r_val << 5) | (g_val << 2) | b_val
                
                f.write(f"{pixel_count:X}: {color:02X};\n")
                pixel_count += 1
        
        # 结束MIF文件
        f.write("END;\n")

# 使用脚本
image_to_mif("message.png", "start_screen.mif", format='B3G3R2')