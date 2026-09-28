"""Generate the original, bundled sine-wave alarm. Uses only Python's stdlib."""
from array import array
from pathlib import Path
import math
import sys
import wave

SAMPLE_RATE = 44100
FREQUENCY = 2400.0
DURATION = 24
AMPLITUDE = 0.92
# Four sharp beeps per 1.2-second group, followed by a short pause.
GROUP_SECONDS = 1.2
PULSE_SECONDS = 0.25
ON_SECONDS = 0.18
EDGE_SECONDS = 0.004  # Short edges avoid clicks without a slow volume ramp.


def generate(output: Path) -> None:
    samples = array('h')
    for index in range(SAMPLE_RATE * DURATION):
        time = index / SAMPLE_RATE
        group_time = time % GROUP_SECONDS
        pulse_time = group_time % PULSE_SECONDS
        envelope = 0.0
        if group_time < 4 * PULSE_SECONDS and pulse_time < ON_SECONDS:
            envelope = min(1.0, pulse_time / EDGE_SECONDS,
                           (ON_SECONDS - pulse_time) / EDGE_SECONDS)
        value = AMPLITUDE * envelope * math.sin(2 * math.pi * FREQUENCY * time)
        samples.append(round(value * 32767))
    if sys.byteorder != 'little':
        samples.byteswap()
    with wave.open(str(output), 'wb') as audio:
        audio.setnchannels(1)
        audio.setsampwidth(2)
        audio.setframerate(SAMPLE_RATE)
        audio.writeframes(samples.tobytes())


if __name__ == '__main__':
    destination = Path(__file__).resolve().parents[1] / 'MikeAgenda/Alarms/electronic_alarm.wav'
    generate(destination)
    print(destination)
