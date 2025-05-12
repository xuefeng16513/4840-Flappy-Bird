import wave

BIT_WIDTH = 8  # 或者16，如果你打算使用更高音质
OUTPUT_FILE = "bgm.mif"

# 读取 wav 文件
wav = wave.open("bgm.wav", "rb")
n_frames = wav.getnframes()
frames = wav.readframes(n_frames)

# 生成 .mif 文件
with open(OUTPUT_FILE, 'w') as f:
    f.write(f"WIDTH={BIT_WIDTH};\n")
    f.write(f"DEPTH={n_frames};\n")
    f.write("ADDRESS_RADIX=UNS;\n")
    f.write("DATA_RADIX=HEX;\n")
    f.write("CONTENT BEGIN\n")
    for i in range(n_frames):
        sample = frames[i]
        f.write(f"{i} : {sample:02X};\n")
    f.write("END;")
