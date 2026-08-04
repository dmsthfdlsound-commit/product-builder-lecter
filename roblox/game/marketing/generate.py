#!/usr/bin/env python3
"""+1 Pop! 티저 — 팝 스케줄(JSON) + 오디오(WAV) 생성. 단일 타임라인 소스."""
import json, math, random, wave, struct, os

random.seed(42)
DUR = 10.0
SR = 44100
COLS, ROWS = 7, 12

# ---------- 팝 스케줄 ----------
pops = []  # {t, col, row, gain}
# 서펜타인 경로 (아래로 훑기)
path = []
for r in range(ROWS):
    cols = range(COLS) if r % 2 == 0 else range(COLS - 1, -1, -1)
    for c in cols:
        path.append((c, r))

t = 0.35
i = 0
# 가속 구간: 0.35s → 6.2s, 간격 0.42 → 0.05 (지수 감소)
while t < 6.2:
    frac = (t - 0.35) / (6.2 - 0.35)
    interval = 0.42 * math.exp(-2.2 * frac) + 0.028
    c, r = path[i % len(path)]
    pops.append({"t": round(t, 3), "col": c, "row": r, "gain": 1})
    t += interval
    i += 1

# 리버스 순간
REBIRTH_T = 6.25
# 프렌지: 6.55 → 7.95, 랜덤 셀, +2
t = 6.55
while t < 7.95:
    c = random.randrange(COLS); r = random.randrange(ROWS)
    pops.append({"t": round(t, 3), "col": c, "row": r, "gain": 2})
    t += random.uniform(0.038, 0.06)

# 엔드카드 축포 3발
for et in (8.35, 8.7, 9.15):
    pops.append({"t": et, "col": random.randrange(COLS), "row": random.randrange(ROWS), "gain": 2})

# 카운터 누적치 계산
total = 0
for p in pops:
    total += p["gain"]
    p["counter"] = total

schedule = {"dur": DUR, "cols": COLS, "rows": ROWS, "rebirthT": REBIRTH_T,
            "endcardT": 8.0, "pops": pops, "finalCounter": total}
out = os.path.dirname(os.path.abspath(__file__))
json.dump(schedule, open(f"{out}/schedule.json", "w"))
print(f"pops={len(pops)} final counter={total}")

# ---------- 오디오 ----------
N = int(DUR * SR)
buf = [0.0] * N

def add(start_s, samples, amp=1.0):
    s0 = int(start_s * SR)
    for k, v in enumerate(samples):
        idx = s0 + k
        if 0 <= idx < N:
            buf[idx] += v * amp

def pop_sound(freq, dur=0.075, vol=0.5):
    n = int(dur * SR)
    out = []
    for k in range(n):
        tt = k / SR
        env = math.exp(-tt * 55)
        # 피치가 살짝 떨어지는 '뽁' + 어택 클릭
        f = freq * (1.0 - 0.25 * tt / dur)
        v = math.sin(2 * math.pi * f * tt) * env
        if k < 40:
            v += (random.random() * 2 - 1) * 0.35 * (1 - k / 40)
        out.append(v * vol)
    return out

def kick(vol=0.55):
    n = int(0.14 * SR)
    return [math.sin(2 * math.pi * (85 * math.exp(-k / SR * 9)) * (k / SR)) *
            math.exp(-(k / SR) * 22) * vol for k in range(n)]

def chime(freq, dur=1.2, vol=0.22):
    n = int(dur * SR)
    return [math.sin(2 * math.pi * freq * k / SR) * math.exp(-(k / SR) * 2.6) * vol
            for k in range(n)]

# 팝들 — 진행될수록 피치 상승(흥분 곡선), 프렌지에선 볼륨 다양화
npops = len(pops)
for j, p in enumerate(pops):
    prog = j / max(1, npops - 1)
    base = 480 + 520 * prog
    freq = base * random.uniform(0.92, 1.1)
    vol = 0.42 if p["t"] < REBIRTH_T else random.uniform(0.3, 0.45)
    add(p["t"], pop_sound(freq, vol=vol))

# 킥: 3.6s부터 리버스까지 0.5s 간격
kt = 3.6
while kt < REBIRTH_T:
    add(kt, kick())
    kt += 0.5

# 라이저: 5.2→6.25 노이즈 스웰
rn = int((REBIRTH_T - 5.2) * SR)
riser = []
prev = 0.0
for k in range(rn):
    fr = k / rn
    prev = prev * 0.82 + (random.random() * 2 - 1) * 0.18  # 저역 필터 흉내
    riser.append(prev * (fr ** 2) * 0.5)
add(5.2, riser)

# 리버스 히트: 붐 + 상승 차임
add(REBIRTH_T, kick(vol=1.0))
add(REBIRTH_T, chime(523.25, vol=0.3))          # C5
add(REBIRTH_T + 0.08, chime(659.25, vol=0.26))  # E5
add(REBIRTH_T + 0.16, chime(783.99, vol=0.26))  # G5

# 엔드카드 코드 (C major add9, 부드럽게)
for f, v in ((261.63, 0.20), (329.63, 0.17), (392.0, 0.17), (587.33, 0.12)):
    add(8.05, chime(f, dur=1.9, vol=v))

# 마스터: 소프트 클립 + 페이드아웃
for k in range(N):
    v = max(-1.0, min(1.0, buf[k] * 0.9))
    v = math.tanh(v * 1.2) / math.tanh(1.2)
    if k > N - SR // 2:
        v *= (N - k) / (SR // 2)
    buf[k] = v

with wave.open(f"{out}/audio.wav", "w") as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
    frames = bytearray()
    for v in buf:
        s = int(v * 32767)
        frames += struct.pack("<hh", s, s)
    w.writeframes(bytes(frames))
print("audio.wav OK")
