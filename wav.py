input_wav = 'bgm.wav'
output_hex = 'bgm.hex'

with open(input_wav, 'rb') as wav_file:
    wav_file.seek(44)
    data = wav_file.read()

with open(output_hex, 'w') as hex_file:
    for i, byte in enumerate(data):
        hex_file.write(f'{byte:02X} ')
        if (i + 1) % 16 == 0:
            hex_file.write('\n')

print(f"Converted {input_wav} to {output_hex} as hex format.")
