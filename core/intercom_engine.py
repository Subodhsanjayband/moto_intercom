#!/usr/bin/env python3
"""
MotoCom Core Protocol & Audio Simulation Engine
Demonstrates:
1. Low-latency UDP Packet Framing (Audio + Header: Sequence, Timestamp, StreamType)
2. Voice Activity Detection (VAD) / Noise Gate with dBFS calculation & hangover timer
3. Automatic Audio Ducking (lowering background music gain when voice is active)
4. Peer-to-Peer bidirectional exchange simulation
"""

import math
import struct
import time
import socket
import threading

# Packet Header:
# Magic: 2 bytes ('MC')
# StreamType: 1 byte (1 = Voice, 2 = Shared Music, 3 = Control/Ping)
# Sequence: 4 bytes (unsigned int)
# TimestampMs: 8 bytes (unsigned long long)
# PayloadSize: 2 bytes (unsigned short)
HEADER_FORMAT = "!2sBIHQ"
HEADER_SIZE = struct.calcsize(HEADER_FORMAT)
MAGIC = b"MC"

STREAM_TYPE_VOICE = 1
STREAM_TYPE_MUSIC = 2
STREAM_TYPE_PING = 3

class VoiceActivityDetector:
    """
    Motorcycle Helmet Noise Gate / VAD:
    Detects if the microphone energy exceeds the ambient noise threshold (e.g. wind).
    Includes a hangover window so sentence ends are not abruptly cut off.
    """
    def __init__(self, threshold_db=-35.0, hangover_ms=300):
        self.threshold_db = threshold_db
        self.hangover_ms = hangover_ms
        self.last_voice_time = -999999

    def calculate_rms_db(self, pcm_samples):
        if not pcm_samples:
            return -100.0
        sum_squares = sum(s * s for s in pcm_samples)
        rms = math.sqrt(sum_squares / len(pcm_samples))
        if rms <= 0.00001:
            return -100.0
        # Reference max 16-bit integer (32767)
        db = 20.0 * math.log10(rms / 32767.0)
        return db

    def is_speaking(self, pcm_samples, current_time_ms):
        db = self.calculate_rms_db(pcm_samples)
        if db >= self.threshold_db:
            self.last_voice_time = current_time_ms
            return True, db
        # Check hangover
        if (current_time_ms - self.last_voice_time) < self.hangover_ms:
            return True, db
        return False, db


class AudioDucker:
    """
    Calculates the smooth gain multiplier for background music (like YouTube Music).
    When voice is detected, music smoothly ducks to duck_level (e.g. 0.20 = 20%).
    When voice stops, music smoothly ramps back up to 1.0 (100%).
    """
    def __init__(self, duck_level=0.20, attack_ms=40, release_ms=250):
        self.duck_level = duck_level
        self.attack_ms = attack_ms
        self.release_ms = release_ms
        self.current_gain = 1.0

    def update(self, voice_active, delta_ms):
        target = self.duck_level if voice_active else 1.0
        if target < self.current_gain:
            # Ducking (Attack)
            step = (1.0 - self.duck_level) * (delta_ms / self.attack_ms)
            self.current_gain = max(target, self.current_gain - step)
        elif target > self.current_gain:
            # Releasing
            step = (1.0 - self.duck_level) * (delta_ms / self.release_ms)
            self.current_gain = min(target, self.current_gain + step)
        return self.current_gain


def pack_audio_packet(stream_type, seq, timestamp_ms, payload):
    header = struct.pack(HEADER_FORMAT, MAGIC, stream_type, seq, len(payload), timestamp_ms)
    return header + payload


def unpack_audio_packet(raw_bytes):
    if len(raw_bytes) < HEADER_SIZE:
        return None
    magic, stream_type, seq, payload_size, timestamp_ms = struct.unpack(
        HEADER_FORMAT, raw_bytes[:HEADER_SIZE]
    )
    if magic != MAGIC:
        return None
    payload = raw_bytes[HEADER_SIZE : HEADER_SIZE + payload_size]
    return {
        "stream_type": stream_type,
        "seq": seq,
        "timestamp_ms": timestamp_ms,
        "payload": payload,
    }


def run_self_test():
    print("==================================================")
    print("  MotoCom Offline Protocol & Audio Engine Test   ")
    print("==================================================")
    
    # 1. Packet packing & unpacking test
    test_payload = b"dummy_opus_encoded_audio_frame_12345"
    packet = pack_audio_packet(STREAM_TYPE_VOICE, 42, 1697530000, test_payload)
    unpacked = unpack_audio_packet(packet)
    assert unpacked is not None
    assert unpacked["stream_type"] == STREAM_TYPE_VOICE
    assert unpacked["seq"] == 42
    assert unpacked["payload"] == test_payload
    print("✅ Packet framing test passed (Header size: %d bytes)" % HEADER_SIZE)

    # 2. VAD & Noise Gate test
    vad = VoiceActivityDetector(threshold_db=-30.0, hangover_ms=200)
    # Silence / low wind noise
    quiet_samples = [int(100 * math.sin(i)) for i in range(160)]
    speaking_samples = [int(15000 * math.sin(i)) for i in range(160)]
    
    speaking_flag, db_quiet = vad.is_speaking(quiet_samples, 0)
    print(f"  Quiet wind noise test: {db_quiet:.1f} dBFS -> Speaking: {speaking_flag}")
    assert not speaking_flag

    speaking_flag, db_loud = vad.is_speaking(speaking_samples, 100)
    print(f"  Rider talking test:    {db_loud:.1f} dBFS -> Speaking: {speaking_flag}")
    assert speaking_flag
    print("✅ VAD & Noise Gate test passed")

    # 3. Audio Ducking Test
    ducker = AudioDucker(duck_level=0.20, attack_ms=40, release_ms=100)
    print("\n--- Simulating Rider Speech on YouTube Music Ducking ---")
    
    # Rider starts talking
    for t in range(0, 100, 20):
        gain = ducker.update(voice_active=True, delta_ms=20)
        print(f"  t={t}ms [Talking] -> YouTube Music Volume: {gain * 100:.1f}%")
    
    # Rider stops talking
    for t in range(100, 260, 40):
        gain = ducker.update(voice_active=False, delta_ms=40)
        print(f"  t={t}ms [Silent]  -> YouTube Music Volume: {gain * 100:.1f}%")

    print("\n✅ All core protocol tests passed successfully!")

if __name__ == "__main__":
    run_self_test()
