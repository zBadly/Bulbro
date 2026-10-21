class_name ParticleFx
extends Node2D
## Vorbereitete GPUParticles2D-Emitter pro Effekttyp, reihum wiederverwendet (kein Erzeugen zur Laufzeit).
## Aufruf über Fx.particles(tree, typ, position, richtung).

enum Kind { DEATH, MUZZLE, HIT, LEVEL_UP, EXPLOSION, HEAL, ICE_POP, FROST, ICE_BURST, ZAP }

const GROUP: StringName = &"particle_fx"
const EMITTERS_PER_KIND: int = 10
const DOT: Texture2D = preload("res://art/fx/particle_dot.svg")
const SHARD: Texture2D = preload("res://art/fx/particle_shard.svg")

## Voreinstellungen: Anzahl, Lebensdauer, Tempo min/max, Streuung (Grad), Größe min/max, Textur, Farben (Start -> Ende).
const PRESETS: Dictionary = {
	Kind.DEATH: {"amount": 16, "lifetime": 0.5, "speed": Vector2(120, 320), "spread": 180.0, "scale": Vector2(0.6, 1.2),
		"texture": "dot", "colors": [Color("#C9A8F2"), Color("#5B3F8C00")], "damping": 400.0},
	Kind.MUZZLE: {"amount": 6, "lifetime": 0.14, "speed": Vector2(150, 320), "spread": 22.0, "scale": Vector2(0.4, 0.8),
		"texture": "dot", "colors": [Color("#FFF4B8"), Color("#FFD43B00")], "damping": 600.0},
	Kind.HIT: {"amount": 5, "lifetime": 0.25, "speed": Vector2(100, 240), "spread": 70.0, "scale": Vector2(0.5, 0.9),
		"texture": "shard", "colors": [Color("#FFFFFF"), Color("#C9A8F200")], "damping": 500.0},
	Kind.LEVEL_UP: {"amount": 40, "lifetime": 0.9, "speed": Vector2(60, 180), "spread": 180.0, "scale": Vector2(0.6, 1.3),
		"texture": "dot", "colors": [Color("#FFE066"), Color("#FFD43B00")], "damping": 80.0, "gravity": -120.0},
	Kind.EXPLOSION: {"amount": 28, "lifetime": 0.45, "speed": Vector2(200, 520), "spread": 180.0, "scale": Vector2(0.7, 1.5),
		"texture": "dot", "colors": [Color("#FFD43B"), Color("#FF8C4200")], "damping": 700.0},
	Kind.HEAL: {"amount": 14, "lifetime": 0.6, "speed": Vector2(40, 120), "spread": 180.0, "scale": Vector2(0.5, 1.0),
		"texture": "dot", "colors": [Color("#7ED957"), Color("#7ED95700")], "damping": 60.0, "gravity": -160.0},
	# Eis-Pop beim Einfrieren
	Kind.ICE_POP: {"amount": 9, "lifetime": 0.4, "speed": Vector2(90, 220), "spread": 180.0, "scale": Vector2(0.6, 1.1),
		"texture": "shard", "colors": [Color("#E6FAFF"), Color("#8FE3FF00")], "damping": 420.0, "gravity": 240.0},
	# Eiskristalle, die verlangsamte Gegner verlieren (viele gleichzeitig möglich)
	Kind.FROST: {"amount": 4, "lifetime": 0.6, "speed": Vector2(15, 50), "spread": 180.0, "scale": Vector2(0.7, 1.1),
		"texture": "shard", "colors": [Color("#E6FAFF"), Color("#8FE3FF00")], "damping": 20.0, "gravity": 70.0, "emitters": 40},
	# Splitter der Frostnova
	Kind.ICE_BURST: {"amount": 22, "lifetime": 0.45, "speed": Vector2(220, 480), "spread": 180.0, "scale": Vector2(0.6, 1.2),
		"texture": "shard", "colors": [Color("#FFFFFF"), Color("#8FE3FF00")], "damping": 650.0},
	# Funken an Kettenblitz-Zielen
	Kind.ZAP: {"amount": 7, "lifetime": 0.2, "speed": Vector2(140, 320), "spread": 180.0, "scale": Vector2(0.4, 0.8),
		"texture": "shard", "colors": [Color("#FFFFFF"), Color("#8FE3FF00")], "damping": 900.0, "emitters": 16},
}

var _emitters: Dictionary[int, Array] = {}
var _next: Dictionary[int, int] = {}


func _ready() -> void:
	add_to_group(GROUP)
	for kind: int in PRESETS:
		var material: ParticleProcessMaterial = _make_material(PRESETS[kind])
		var list: Array[GPUParticles2D] = []
		for i in int(PRESETS[kind].get("emitters", EMITTERS_PER_KIND)):
			list.append(_make_emitter(PRESETS[kind], material))
		_emitters[kind] = list
		_next[kind] = 0


func emit(kind: Kind, at: Vector2, direction: Vector2 = Vector2.ZERO) -> void:
	var list: Array = _emitters[kind]
	var emitter: GPUParticles2D = list[_next[kind]]
	_next[kind] = (_next[kind] + 1) % list.size()
	emitter.global_position = at
	emitter.rotation = direction.angle() if direction != Vector2.ZERO else 0.0
	emitter.restart()


func _make_emitter(preset: Dictionary, material: ParticleProcessMaterial) -> GPUParticles2D:
	var emitter: GPUParticles2D = GPUParticles2D.new()
	emitter.amount = preset["amount"]
	emitter.lifetime = preset["lifetime"]
	emitter.one_shot = true
	emitter.explosiveness = 1.0
	emitter.emitting = false
	emitter.local_coords = false
	emitter.texture = SHARD if preset["texture"] == "shard" else DOT
	emitter.process_material = material
	add_child(emitter)
	return emitter


func _make_material(preset: Dictionary) -> ParticleProcessMaterial:
	var material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	material.direction = Vector3(1, 0, 0)
	material.spread = preset["spread"]
	material.initial_velocity_min = preset["speed"].x
	material.initial_velocity_max = preset["speed"].y
	material.gravity = Vector3(0, preset.get("gravity", 0.0), 0)
	material.damping_min = preset["damping"]
	material.damping_max = preset["damping"]
	material.scale_min = preset["scale"].x
	material.scale_max = preset["scale"].y
	material.angle_min = -180.0
	material.angle_max = 180.0
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, preset["colors"][0])
	ramp.set_color(1, preset["colors"][1])
	var ramp_texture: GradientTexture1D = GradientTexture1D.new()
	ramp_texture.gradient = ramp
	material.color_ramp = ramp_texture
	return material
