"""Reproducible original Bara sound design. Python stdlib; PCM16 mono 48 kHz.
No samples from anime or third-party recordings. Peaks normalized to -3.0 dBFS.
Run: python3 tools/generate_bara_audio.py
"""
from pathlib import Path
import math, random, wave, struct, json
ROOT=Path(__file__).resolve().parents[1]; RATE=48000
OUT=ROOT/'assets/audio'; OUT.mkdir(parents=True,exist_ok=True)
report={}
for cue,duration,seed in [('split',.28,11),('shot',.75,12),('impact',.32,13),('return',.25,14),('blast',1.18,15)]:
    rng=random.Random(seed); samples=[]; low=0.;phase=0.
    for i in range(round(RATE*duration)):
        t=i/RATE; q=t/duration; noise=rng.uniform(-1,1);low=.94*low+.06*noise
        attack=min(1,t/.002);tail=min(1,(duration-t)/.018)
        if cue=='split':
            phase+=2*math.pi*(720-540*q)/RATE
            value=.56*noise*math.exp(-t*32)+.32*math.sin(phase)*math.exp(-t*19)+.50*low*math.exp(-t*9)
        elif cue=='shot':
            phase+=2*math.pi*(110*math.exp(-t*6)+38)/RATE
            value=.50*math.sin(phase)*math.exp(-t*7)+noise*.82*math.exp(-t*42)+low*1.8*math.exp(-t*5)
            value+=.10*math.sin(2*math.pi*420*t)*math.exp(-t*17)
        elif cue=='impact':
            phase+=2*math.pi*(180*math.exp(-t*17)+62)/RATE
            value=.75*math.sin(phase)*math.exp(-t*22)+.48*noise*math.exp(-t*36)+low*.6*math.exp(-t*11)
        elif cue=='return':
            phase+=2*math.pi*(360+880*q*q)/RATE
            swell=math.sin(min(1,q/.72)*math.pi*.5)
            value=.27*math.sin(phase)*swell*math.exp(-t*8)+.30*low*math.sin(q*math.pi)
            if t>.17:value+=.6*noise*math.exp(-(t-.17)*130)
        else:
            phase+=2*math.pi*(84*math.exp(-t*4)+31)/RATE
            value=.6*math.sin(phase)*math.exp(-t*3.9)+noise*.65*math.exp(-t*29)+low*2.5*math.exp(-t*3.4)
            value+=.10*noise*(.5+.5*math.sin(t*57))*math.exp(-t*4)
        samples.append(value*attack*tail)
    peak=max(abs(x) for x in samples);scale=10**(-3/20)/peak
    pcm=[round(max(-1,min(1,x*scale))*32767) for x in samples]
    with wave.open(str(OUT/('bara_'+cue+'.wav')),'wb') as f:
        f.setnchannels(1);f.setsampwidth(2);f.setframerate(RATE);f.writeframes(struct.pack('<%dh'%len(pcm),*pcm))
    rms=math.sqrt(sum((x/32767)**2 for x in pcm)/len(pcm))
    report[cue]={'duration_seconds':duration,'peak_dbfs':20*math.log10(max(abs(x) for x in pcm)/32767),'rms_dbfs':20*math.log10(rms),'rate_hz':RATE,'channels':1,'bits':16}
path=ROOT/'art_src/bara_bara/audio_measurements.json';path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
