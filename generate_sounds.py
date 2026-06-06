import wave
import struct
import math
import random
import os

os.makedirs('assets/sounds', exist_ok=True)

def generate_wav(filename, duration, sample_rate=44100, func=None):
    with wave.open(filename, 'w') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(sample_rate)
        
        num_samples = int(duration * sample_rate)
        for i in range(num_samples):
            t = float(i) / sample_rate
            val = func(t, i, num_samples)
            # clamp
            val = max(-1.0, min(1.0, val))
            # convert to 16-bit
            int_val = int(val * 32767.0)
            data = struct.pack('<h', int_val)
            f.writeframesraw(data)

# Gunshot - white noise with fast decay
def gunshot(t, i, n):
    env = math.exp(-t * 30.0)
    noise = random.uniform(-1.0, 1.0)
    return noise * env

# Hit confirm - short high pitched beep
def hit_confirm(t, i, n):
    env = math.exp(-t * 20.0)
    freq = 800.0 + (1.0 - t/0.1) * 400.0 if t < 0.1 else 800.0
    return math.sin(2 * math.pi * freq * t) * env * 0.5

# Footstep - low thud
def footstep(t, i, n):
    env = math.exp(-t * 40.0)
    return math.sin(2 * math.pi * 60.0 * t) * env * random.uniform(0.5, 1.0)

generate_wav('assets/sounds/gunshot.wav', 0.5, func=gunshot)
generate_wav('assets/sounds/hit.wav', 0.2, func=hit_confirm)
generate_wav('assets/sounds/footstep.wav', 0.15, func=footstep)
print("Sounds generated!")
