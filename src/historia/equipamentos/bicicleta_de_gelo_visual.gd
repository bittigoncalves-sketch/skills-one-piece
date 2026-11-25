extends Node3D
## Fonte editável da bicicleta: rodas raiadas, quadro diamantado, garfo e pedaleira.
var rodas: Array[Node3D] = []
var pedais: Node3D
var gelo: StandardMaterial3D
var borda: StandardMaterial3D

func _ready() -> void:
	gelo = StandardMaterial3D.new()
	gelo.albedo_color = Color("a6e0f2")
	gelo.metallic = .25
	gelo.roughness = .19
	gelo.emission_enabled = true
	gelo.emission = Color("22566c")
	gelo.emission_energy_multiplier = .35
	borda = gelo.duplicate()
	borda.albedo_color = Color("e2f9ff")
	borda.roughness = .3
	for z: float in [-.78, .78]:
		var roda := Node3D.new()
		add_child(roda)
		roda.position = Vector3(0,.46,z)
		rodas.append(roda)
		var aro := TorusMesh.new()
		aro.inner_radius = .405
		aro.outer_radius = .46
		aro.rings = 40
		aro.ring_segments = 12
		var mi := _malha(roda, aro, gelo)
		mi.rotation.z = PI / 2
		for i in 16:
			var angulo := TAU * i / 16
			_tubo(roda, Vector3.ZERO, Vector3(0, sin(angulo), cos(angulo)) * .405, .008, borda)
		_tubo(roda, Vector3(-.10,0,0), Vector3(.10,0,0), .065, borda)
	var eixo := Vector3(0,.43,.06)
	var sela := Vector3(0,1.05,.28)
	var direcao := Vector3(0,1.02,-.57)
	var traseiro := Vector3(0,.46,.78)
	for par: Array in [[eixo,sela], [sela,direcao], [direcao,eixo], [sela,traseiro], [traseiro,eixo]]:
		_tubo(self, par[0], par[1], .045, gelo)
	for lado: float in [-1.0,1.0]:
		_tubo(self, direcao + Vector3(lado*.08,0,0), Vector3(lado*.08,.46,-.78), .03, borda)
	_tubo(self, sela, sela + Vector3.UP * .10, .025, borda)
	var banco := CapsuleMesh.new()
	banco.radius = .105
	banco.height = .34
	var assento := _malha(self, banco, borda)
	assento.position = sela + Vector3.UP*.13
	assento.rotation.x = PI / 2
	_tubo(self, direcao, Vector3(0,1.30,-.60), .032, gelo)
	_tubo(self, Vector3(-.35,1.30,-.60), Vector3(.35,1.30,-.60), .032, gelo)
	for lado: float in [-1.0,1.0]:
		_tubo(self, Vector3(lado*.35,1.30,-.60), Vector3(lado*.35,1.30,-.43), .04, borda)
	pedais = Node3D.new()
	add_child(pedais)
	pedais.position = eixo
	for lado: float in [-1.0,1.0]:
		var p := Vector3(lado*.15, lado*.16, 0)
		_tubo(pedais, Vector3(lado*.15,0,0), p, .025, borda)
		_tubo(pedais, p, p + Vector3(lado*.16,0,0), .045, gelo)

func animar(distancia: float, fase: float) -> void:
	for roda in rodas: roda.rotation.x -= distancia / .46
	pedais.rotation.x = fase

func _malha(pai: Node3D, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var no := MeshInstance3D.new()
	no.mesh = mesh
	no.material_override = mat
	pai.add_child(no)
	return no

func _tubo(pai: Node3D, a: Vector3, b: Vector3, raio: float, mat: Material) -> void:
	var cilindro := CylinderMesh.new()
	cilindro.top_radius = raio
	cilindro.bottom_radius = raio
	cilindro.height = a.distance_to(b)
	cilindro.radial_segments = 12
	var no := _malha(pai, cilindro, mat)
	no.position = (a+b)*.5
	no.quaternion = Quaternion(Vector3.UP, (b-a).normalized())
