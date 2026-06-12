#!/usr/bin/env python3
"""WordDuel ses efektlerini sentezler.

Harici örnek/lisans bağımlılığı olmasın diye tüm efektler saf Python ile
(sinüs kısmi harmonikleri + üstel zarf) üretilir ve depoya WAV olarak girer.

Kullanım: python3 scripts/make_sounds.py
Çıktı:    App/Resources/Sounds/*.wav (44.1 kHz, 16-bit, mono)
"""

import math
import struct
import wave
from pathlib import Path

RATE = 44100
OUT_DIR = Path(__file__).resolve().parent.parent / "App" / "Resources" / "Sounds"

# Nota frekansları (Hz)
A3, C4, E4 = 220.00, 261.63, 329.63
C5, E5, G5 = 523.25, 659.25, 783.99
C6, E6, G6 = 1046.50, 1318.51, 1567.98


def bell(freq, dur, amp=0.5, partials=((1.0, 1.0), (2.0, 0.4), (3.0, 0.15)), decay=6.0):
    """Çan/marimba benzeri ton: kısmi harmonikler + üstel sönüm."""
    n = int(RATE * dur)
    out = [0.0] * n
    for mult, level in partials:
        f = freq * mult
        if f >= RATE / 2:
            continue
        for i in range(n):
            t = i / RATE
            attack = min(1.0, t / 0.004)
            env = attack * math.exp(-decay * t * (1.0 + 0.3 * (mult - 1.0)))
            out[i] += amp * level * env * math.sin(2 * math.pi * f * t)
    return out


def glide(f0, f1, dur, amp=0.3):
    """Frekansı kayan, Hann zarflı yumuşak 'swoosh' tonu."""
    n = int(RATE * dur)
    out = []
    phase = 0.0
    for i in range(n):
        u = i / max(1, n - 1)
        f = f0 + (f1 - f0) * u
        phase += 2 * math.pi * f / RATE
        out.append(amp * math.sin(math.pi * u) * math.sin(phase))
    return out


def mix(buffer, sound, at=0.0):
    """`sound`u `buffer` içine `at` saniyesinden itibaren toplar."""
    start = int(RATE * at)
    need = start + len(sound)
    if need > len(buffer):
        buffer.extend([0.0] * (need - len(buffer)))
    for i, s in enumerate(sound):
        buffer[start + i] += s


def write(name, samples):
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    peak = max(1e-9, max(abs(s) for s in samples))
    scale = min(1.0, 0.88 / peak)
    path = OUT_DIR / f"{name}.wav"
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(
            b"".join(
                struct.pack("<h", int(max(-1.0, min(1.0, s * scale)) * 32767))
                for s in samples
            )
        )
    print(f"{path.relative_to(OUT_DIR.parent.parent.parent)}  ({len(samples) / RATE:.2f} sn)")


def main():
    # Geri sayımın son saniyelerinde çalan kısa, tahta blok benzeri tik.
    tick = []
    mix(tick, bell(1900, 0.06, amp=0.45, partials=((1.0, 1.0), (0.5, 0.5)), decay=70))
    write("tick", tick)

    # Süre doldu: alçalan iki kısa uyarı tonu.
    timeup = []
    mix(timeup, bell(660, 0.20, amp=0.5, decay=16), at=0.0)
    mix(timeup, bell(440, 0.40, amp=0.5, decay=9), at=0.16)
    write("timeup", timeup)

    # Doğru cevap: yükselen majör üçlü (klasik başarı çanı).
    correct = []
    mix(correct, bell(C6, 0.30, amp=0.45, decay=9), at=0.0)
    mix(correct, bell(E6, 0.50, amp=0.45, decay=7), at=0.11)
    write("correct", correct)

    # Yanlış cevap: pes, yumuşak çift "bızz".
    wrong = []
    low = ((1.0, 1.0), (3.0, 0.35), (5.0, 0.12))
    mix(wrong, bell(185, 0.14, amp=0.5, partials=low, decay=22), at=0.0)
    mix(wrong, bell(165, 0.22, amp=0.5, partials=low, decay=16), at=0.16)
    write("wrong", wrong)

    # Kelime/cevap gönderme: hafif yükselen swoosh.
    write("send", glide(500, 980, 0.14, amp=0.32))

    # Zafer: yükselen arpej + final akoru + tepede ışıltılar (konfeti eşliği).
    victory = []
    for i, note in enumerate((C5, E5, G5, C6)):
        mix(victory, bell(note, 0.40, amp=0.38, decay=8), at=0.12 * i)
    for note, level in ((C6, 0.34), (E6, 0.28), (G6, 0.22)):
        mix(victory, bell(note, 1.30, amp=level, decay=3.0), at=0.55)
    for i, f in enumerate((2093, 2637, 3136)):
        mix(victory, bell(f, 0.35, amp=0.10, decay=10), at=0.75 + 0.14 * i)
    write("victory", victory)

    # Yenilgi: alçalan üç yumuşak nota — üzgün ama nazik.
    defeat = []
    mellow = ((1.0, 1.0), (2.0, 0.2))
    for i, note in enumerate((E4, C4, A3)):
        mix(defeat, bell(note, 0.60, amp=0.40, partials=mellow, decay=5.0), at=0.25 * i)
    write("defeat", defeat)

    # Beraberlik: nötr, eşit iki vuruş.
    tie = []
    mix(tie, bell(G5, 0.25, amp=0.40, decay=10), at=0.0)
    mix(tie, bell(G5, 0.45, amp=0.40, decay=7), at=0.20)
    write("tie", tie)


if __name__ == "__main__":
    main()
