import wave
import struct
import random
import math

def generate_wav(filename, duration, sample_rate, wave_type, freq_start, freq_end=None):
    num_samples = int(duration * sample_rate)
    
    with wave.open(filename, 'w') as wav_file:
        wav_file.setnchannels(1) # Mono
        wav_file.setsampwidth(2) # 16-bit
        wav_file.setframerate(sample_rate)
        
        for i in range(num_samples):
            t = float(i) / sample_rate
            
            # Envelope (fade out)
            envelope = max(0, 1.0 - (t / duration))
            
            value = 0
            if wave_type == 'noise':
                # White noise for footsteps (like grass/dirt)
                value = random.uniform(-1.0, 1.0)
                # Lowpass filter roughly
                if i % 2 == 0: value *= 0.5
            elif wave_type == 'sine':
                # Frequency sweep for jump/land
                current_freq = freq_start
                if freq_end:
                    current_freq = freq_start + (freq_end - freq_start) * (t / duration)
                value = math.sin(2.0 * math.pi * current_freq * t)
            
            # Reduce volume
            value *= 0.5 * envelope
            
            # Convert to 16-bit integer
            sample = int(value * 32767.0)
            sample = max(-32768, min(32767, sample))
            
            wav_file.writeframes(struct.pack('<h', sample))

# Generate footstep 1 (short noise)
generate_wav('/home/gabriel-bitti/dev/skills-one-piece/assets/audio/footsteps/grass/step_01.wav', 0.15, 44100, 'noise', 0)
# Generate footstep 2 (short noise)
generate_wav('/home/gabriel-bitti/dev/skills-one-piece/assets/audio/footsteps/grass/step_02.wav', 0.13, 44100, 'noise', 0)
# Generate jump (sweep up)
generate_wav('/home/gabriel-bitti/dev/skills-one-piece/assets/audio/movement/jump.wav', 0.3, 44100, 'sine', 150, 400)
# Generate land (sweep down + shorter)
generate_wav('/home/gabriel-bitti/dev/skills-one-piece/assets/audio/movement/land.wav', 0.2, 44100, 'sine', 200, 50)

print("Generated dummy audio files successfully.")
