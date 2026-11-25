// ============================================================================
//  LUZ EM FAIXAS (cel) para shaders NOVOS que precisam de albedo próprio
//  (14/10/2026, docs/MAR_HISTORIA_PLANO.md: fundo do mar, corais, peixes).
//
//  É a MESMA conta do `light()` de `src/fx/shaders/cel.gdshader` (Fase 3 do
//  docs/PLANO_VISUAL.md) — leia lá o porquê do piso, da borda estreita e da sombra
//  como teto. O `cel.gdshader` ainda tem a cópia dele: não foi tocado nesta frente
//  (é compartilhado por tudo e havia outra sessão ativa).
//  ⚠️ GATILHO: a próxima mudança na luz do `cel.gdshader` passa a incluir ESTE
//  arquivo, para a conta voltar a ter uma fonte só.
//
//  Uso: `#include "res://src/fx/shaders/luz_cel.gdshaderinc"` depois do
//  `shader_type`/`render_mode` (com `specular_disabled, diffuse_lambert`).
// ============================================================================

uniform int faixas : hint_range(2, 5) = 3;
uniform float suavidade : hint_range(0.005, 0.2) = 0.035;
uniform float sombra_min : hint_range(0.0, 0.9) = 0.16;

void light() {
	float ndl = max(dot(normalize(NORMAL), normalize(LIGHT)), 0.0);
	float passo = 1.0 / float(faixas);
	float idx = floor(ndl / passo);
	float f = fract(ndl / passo);
	float degrau = (idx + smoothstep(0.5 - suavidade, 0.5 + suavidade, f)) * passo;
	float luz = mix(sombra_min, 1.0, clamp(degrau, 0.0, 1.0));
	if (LIGHT_IS_DIRECTIONAL) {
		// Sol/lua: ATTENUATION é só a sombra → entra como teto (ver cel.gdshader).
		float som = smoothstep(0.35, 0.65, ATTENUATION);
		luz = min(luz, mix(sombra_min, 1.0, som));
	} else {
		// Omni/spot: ATTENUATION carrega a DISTÂNCIA e vai a zero no alcance. Como teto,
		// o piso vazava a luz inteira para fora do alcance, no formato dos blocos de tela
		// do Forward+ (foto da E3, 14/10/2026 — a LuzSubaquatica acendia quadrados).
		luz *= ATTENUATION;
	}
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * luz;
}
