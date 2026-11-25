shader_type spatial;
render_mode cull_disabled;
// Lava ativa: crosta escura rachada por veios incandescentes (vermelho -> laranja -> amarelo),
// com fluxo lento e pulso de brilho. `fria` apaga tudo e vira pedra (lava solidificada pela água).
uniform float fria : hint_range(0.0, 1.0) = 0.0;
uniform float fluxo = 1.0;
varying vec3 ponto;
float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1,311.7,74.7))) * 43758.5453); }
float ruido(vec3 p) {
 vec3 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex(){ ponto=VERTEX*length(MODEL_MATRIX[0].xyz); }
void fragment(){
 float t=TIME*fluxo;
 vec3 p=ponto*2.6+vec3(t*0.05,-t*0.16,t*0.04);
 // Ruído deformado por ele mesmo: veios sinuosos em vez de manchas redondas.
 vec3 q=p+vec3(ruido(p*1.7+t*0.1),ruido(p*1.7+7.3),ruido(p*1.7-t*0.08))*0.9;
 float n=ruido(q)*0.65+ruido(q*2.3)*0.35;
 // Quanto mais perto de n=0.5, mais fundo o veio de lava; fora disso, crosta.
 float calor=1.0-smoothstep(0.0,0.15,abs(n-0.5));
 calor=pow(calor,0.8);
 float pulso=0.88+0.12*sin(t*2.2+n*12.0);
 vec3 crosta=mix(vec3(0.03,0.015,0.012),vec3(0.16,0.045,0.02),ruido(q*4.0));
 vec3 lava=mix(vec3(0.85,0.04,0.0),vec3(1.0,0.38,0.02),smoothstep(0.0,0.5,calor));
 lava=mix(lava,vec3(1.0,0.88,0.22),smoothstep(0.82,1.0,calor));
 // Entre a crosta e o veio, uma borda vermelha viva (a crosta também brilha ao redor).
 float brilho=smoothstep(0.0,0.9,calor);
 vec3 cor=mix(crosta,lava,brilho);
 ALBEDO=mix(cor*0.6,vec3(0.12,0.13,0.15),fria);
 EMISSION=(lava*brilho*2.0*pulso+vec3(0.35,0.03,0.0)*(1.0-brilho)*0.4)*(1.0-fria);
 ROUGHNESS=mix(0.6,0.92,fria);
}
