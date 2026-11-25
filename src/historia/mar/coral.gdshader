// ============================================================================
//  CORAL — material da vida de recife (14/10/2026, docs/MAR_HISTORIA_PLANO.md, E2).
//
//  Direção de arte do dono (14/10): "One Piece vibrante". A COR vem daqui, por
//  instância; o modelo (tools/blender/corais.py) só traz MÁSCARAS na cor do vértice:
//    R gradiente base → ponta · G oclusão ambiente · B detalhe · A peso do balanço
//  INSTANCE_CUSTOM (MultiMesh): x = paleta (0–1 → 4 pares base/ponta), y = fase do
//  balanço, z = força do balanço da instância, w = variação de brilho.
//  Luz em faixas do mundo, com o piso alto de luz de água (como o fundo do mar).
// ============================================================================
shader_type spatial;
render_mode specular_disabled, diffuse_lambert, cull_disabled;
#include "res://src/fx/shaders/luz_cel.gdshaderinc"

uniform vec4 bases[4];
uniform vec4 pontas[4];
// + clareia (pólipos, pontas), − escurece (sulcos do cérebro).
uniform float detalhe_forca = 0.4;
// Quanto a espécie balança (0 = coral duro; anêmona e alga balançam).
uniform float balanco = 0.0;
uniform float balanco_velocidade = 0.9;

varying flat int paleta;
varying float brilho;

void vertex() {
	paleta = clamp(int(INSTANCE_CUSTOM.x * 4.0), 0, 3);
	brilho = INSTANCE_CUSTOM.w;
	float peso = COLOR.a * balanco * INSTANCE_CUSTOM.z;
	if (peso > 0.0) {
		float t = TIME * balanco_velocidade + INSTANCE_CUSTOM.y * 6.2831;
		// Onda que sobe pelo corpo (a ponta atrasa), em dois eixos.
		VERTEX.x += sin(t - VERTEX.y * 1.1) * peso * 0.22;
		VERTEX.z += sin(t * 0.77 - VERTEX.y * 0.9 + 1.3) * peso * 0.16;
	}
}

void fragment() {
	vec3 base = bases[paleta].rgb;
	vec3 ponta = pontas[paleta].rgb;
	vec3 c = mix(base, ponta, COLOR.r);
	if (detalhe_forca >= 0.0) {
		c = mix(c, min(ponta * 1.2, vec3(1.0)), COLOR.b * detalhe_forca);
	} else {
		c *= 1.0 + COLOR.b * detalhe_forca;
	}
	c *= mix(0.6, 1.0, COLOR.g);             // oclusão gravada no modelo
	c *= brilho;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;                    // fitas da alga, paredes dos tubos
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
