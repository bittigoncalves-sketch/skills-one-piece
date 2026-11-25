shader_type spatial;
render_mode diffuse_burley, specular_disabled;

// BRASA — a superfície SÓLIDA e quente: o punho do Hiken e o núcleo do Entei.
//
// Espelha o papel do `ope_rock.gdshader` (crosta escura + veio emissivo), com a
// polaridade trocada: lá a pedra é fria e a veia é ciano; aqui a crosta é
// carvão e a veia é magma. `heat` abre as fendas — 0 é carvão apagado, 1 é
// metal branco.

uniform float variant = 0.0;
uniform float heat : hint_range(0.0, 1.0) = 1.0;
uniform float age = 0.0;
uniform float displacement : hint_range(0.0, 0.4) = 0.11;
/// ⚠️ TAMANHO DO CORPO, em unidades. O ruído das fendas é normalizado por ele.
/// Sem isso o mesmo shader dá rachadura legível num punho de raio 1 e vira
/// CHUVISCO num sol de raio 7 — foi exatamente o que apareceu na captura
/// `08_entei_carga.png` de 2026-09-08.
uniform float feature_scale = 1.0;
/// Amplitude usada para codificar a posição do bloco em `INSTANCE_CUSTOM`
/// (que guarda 0..1). Tem que casar com o valor de `GEO.fist_blocks`.
uniform float CUSTOM_RANGE = 4.0;
uniform vec4 crust_cold : source_color = vec4(0.045, 0.030, 0.028, 1.0);
uniform vec4 crust_warm : source_color = vec4(0.26, 0.13, 0.075, 1.0);
uniform vec4 vein_color : source_color = vec4(1.0, 0.42, 0.06, 1.0);
uniform vec4 vein_hot   : source_color = vec4(1.0, 0.93, 0.68, 1.0);
/// A cor da crosta quando `heat` é 1. Um corpo chamado SOL não pode ler como
/// asteroide preto; com o calor no máximo a própria superfície é incandescente,
/// não só as fendas.
uniform vec4 crust_hot  : source_color = vec4(0.95, 0.36, 0.06, 1.0);

varying vec3 object_pos;

float crust_noise(vec3 p) {
	return sin(p.x * 4.7 + p.y * 2.1 + variant) * sin(p.z * 5.2 - p.y * 3.2)
		+ 0.45 * sin(p.x * 11.3 + p.z * 4.0) * sin(p.y * 9.7 + variant);
}

void vertex() {
	// A crosta é irregular: o mesmo deslocamento de vértice do ope_rock, para o
	// bloco não ler como caixa. É o que tira o aspecto de voxel do punho.
	float k = 1.0 / max(feature_scale, 0.001);
	VERTEX *= 1.0 + crust_noise(VERTEX * 1.6 * k) * displacement;
	// ⚠️ O PADRÃO TEM QUE SER CONTÍNUO PELO CORPO INTEIRO. Num `MultiMesh` cada
	// bloco compartilha o mesmo `VERTEX` local, então amostrar só por ele dá a
	// MESMA fenda em todos os ~60 cubos — o punho lê como parede de tijolos, com
	// as juntas virando argamassa (medido na captura `03_hiken_punho.png`).
	// `INSTANCE_CUSTOM` carrega a POSIÇÃO do bloco dentro do corpo (codificada
	// em 0..1 por `GEO.fist_blocks`), então a amostra volta a ser a posição real
	// no punho e a rachadura atravessa os blocos. Em malha solta o custom é
	// zero e o termo desaparece.
	vec3 offset_do_bloco = (INSTANCE_CUSTOM.xyz - 0.5) * CUSTOM_RANGE;
	object_pos = (VERTEX + offset_do_bloco) * k;
}

void fragment() {
	float strata = crust_noise(object_pos * 1.7);
	float band = smoothstep(-0.35, -0.28, strata) * 0.25 + smoothstep(0.35, 0.42, strata) * 0.22;
	vec3 crust = mix(crust_cold.rgb, crust_warm.rgb, band + 0.20);
	crust = mix(crust, crust_hot.rgb, smoothstep(0.35, 1.0, heat) * (0.35 + band));

	// As FENDAS. Duas famílias cruzadas dão rachadura, não listra.
	float c1 = 1.0 - smoothstep(0.02, 0.075, abs(sin(object_pos.y * 13.0 + strata * 1.4)));
	float c2 = 1.0 - smoothstep(0.03, 0.095, abs(sin(object_pos.x * 9.5 - object_pos.z * 7.0 + strata)));
	float crack = clamp(c1 + c2 * 0.75, 0.0, 1.0);

	// A fenda respira: o magma pulsa devagar, sem piscar.
	float pulse = 0.78 + 0.22 * sin(age * 3.1 + strata * 2.0);
	float glow = crack * heat * pulse;

	vec3 vein = mix(vein_color.rgb, vein_hot.rgb, smoothstep(0.45, 1.0, glow));

	ALBEDO = crust;
	ROUGHNESS = 0.92;
	// A crosta também brilha quando está muito quente — senão o corpo fica
	// escuro entre as fendas e perde a leitura de "aceso".
	vec3 brilho_de_crosta = crust_hot.rgb * smoothstep(0.5, 1.0, heat) * (0.35 + band * 0.9);
	EMISSION = vein * glow * (1.4 + heat * 3.6) + brilho_de_crosta;
}
