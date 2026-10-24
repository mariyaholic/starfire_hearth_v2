class_name CityBuildingKit
extends RefCounted
## Pure assembly descriptions for Blender-authored, instanced mesh parts.
## Architecture changes silhouettes and arrangement; it never changes game ownership.

const STYLES: Array[String] = ["ark", "meridian", "vael"]


static func _part(parts: Array[Dictionary], mesh: String, role: String, at: Vector3, dimensions: Vector3, rotation: Vector3 = Vector3.ZERO) -> void:
	var basis: Basis = Basis.from_euler(rotation * PI / 180.0) * Basis.from_scale(dimensions)
	parts.append({"mesh": mesh, "role": role, "transform": Transform3D(basis, at)})


static func _box(parts: Array[Dictionary], role: String, x: float, y: float, z: float, width: float, height: float, depth: float, rotation: Vector3 = Vector3.ZERO) -> void:
	_part(parts,"box",role,Vector3(x,y+height*0.5,z),Vector3(width,height,depth),rotation)


static func build(slot: Dictionary, style: String, development: int, terrain_kind: String) -> Array[Dictionary]:
	assert(style in STYLES)
	var parts: Array[Dictionary] = []
	var kind: String = slot["kind"]
	if kind.is_empty() or slot["blocked"]: return parts
	if style == "vael":
		_vael(parts,kind,development,terrain_kind)
		return _varied(parts,slot)
	match kind:
		"habitation":
			for i: int in 3:
				var x: float = (i-1) * 1.02
				var z: float = 0.0 if i != 1 else -0.52
				var h: float = 0.85 + development * 0.65 + (0.45 if style == "meridian" and i == 1 else 0.0)
				_box(parts,"stone",x,0,z,0.98,0.12,1.52)
				_box(parts,"shell",x,0.12,z,0.90,h,1.34)
				_box(parts,"dark",x,h+0.12,z,0.97,0.13,1.43)
				for floor_index: int in development+1:
					for aperture: int in 5:
						var wx: float = x-0.28+aperture*0.14
						_box(parts,"dark",wx,0.40+floor_index*0.62,z+0.675,0.125,0.18,0.055)
						_box(parts,"light",wx,0.43+floor_index*0.62,z+0.707,0.090,0.11,0.012)
				_box(parts,"accent",x,0.22,z-0.68,0.12,h-0.05,0.035)
				_box(parts,"metal",x+0.2,h+0.25,z-0.2,0.30,0.17,0.35)
				for vent: int in 4:
					_box(parts,"dark",x+0.2,h+0.421,z-0.31+vent*0.07,0.24,0.014,0.026)
				_box(parts,"dark",x,0.12,z+0.685,0.20,0.28,0.042)
				_box(parts,"metal",x,0.41,z+0.70,0.36,0.045,0.26)
				if development > 0:
					_box(parts,"solar",x,h+0.30,z+0.32,0.70,0.035,0.53,Vector3(-16,0,0))
			if style == "meridian":
				_part(parts,"dome","metal",Vector3(0,1.42+development*0.65,-0.52),Vector3(0.95,0.40,1.2))
				_part(parts,"cone","accent",Vector3(0,2.18+development*0.65,-0.52),Vector3(0.18,0.77,0.18))
			if development == 2:
				_box(parts,"metal",0,1.2,0.25,2.45,0.12,0.35)
				_part(parts,"cylinder","metal",Vector3(-1.12,3.16,-0.45),Vector3(0.035,1.25,0.035))
				_part(parts,"sphere","accent",Vector3(-1.12,3.79,-0.45),Vector3.ONE*0.09)
		"agriculture":
			for i: int in 2:
				var x: float = -0.82+i*1.64
				_box(parts,"soil",x,0.015,0,1.38,0.07,2.85)
				for row: int in 11:
					_box(parts,"crop",x,0.09,-1.2+row*0.24,1.25,0.11,0.09)
				if development > 0 or terrain_kind != "continental" or i == 1:
					_part(parts,"dome","glass",Vector3(x,0.12,0),Vector3(1.42,0.61,2.85))
					for rib: int in 5:
						_part(parts,"arch","metal",Vector3(x,0.12,-1.16+rib*0.58),Vector3(1.45,1.22,0.45))
			_box(parts,"shell",0,0,1.8,1.0,0.48,0.52)
		"energy":
			for x_index: int in 3:
				for z_index: int in 3:
					var x: float = -1.0+x_index
					var z: float = -1.0+z_index*0.95
					_box(parts,"metal",x,0.04,z,0.09,0.35,0.09)
					_box(parts,"solar",x,0.38,z,0.88,0.045,0.76,Vector3(-24,0,0))
			_box(parts,"shell",0,0,1.55,1.62,0.65,0.62)
			if development > 0:
				_part(parts,"cylinder","metal",Vector3(0,1.15,1.55),Vector3(0.55,0.9,0.55))
				_part(parts,"sphere","accent",Vector3(0,1.62,1.55),Vector3(0.37,0.37,0.37))
		"mining":
			for depth_index: int in 3:
				var edge: float = 0.95-depth_index*0.21
				var y: float = -0.12-depth_index*0.16
				for side: int in [-1,1]:
					_box(parts,"stone",side*edge,y,0,0.16,0.14,edge*2)
					_box(parts,"stone",0,y,side*edge,edge*2,0.14,0.16)
			_box(parts,"dark",0,-0.55,0,1.35,0.06,1.35)
			_box(parts,"shell",1.48,0,0,0.66,0.70+development*0.35,1.65)
			_box(parts,"metal",-1.30,0,0.1,0.20,1.65,0.20)
			_box(parts,"metal",-0.63,1.54,0.1,1.50,0.13,0.18)
			_box(parts,"accent",-0.08,0.6,0.1,0.07,0.94,0.07)
			_box(parts,"dark",0.95,0.3,0.3,0.72,0.12,0.44,Vector3(0,0,-24))
		"industry":
			_box(parts,"stone",0,0,0,2.85,0.15,2.45)
			_box(parts,"shell",0,0.15,0,2.35,0.95+development*0.34,1.85)
			_box(parts,"dark",0,1.10+development*0.34,0,2.55,0.17,2.05)
			for i: int in 2:
				_part(parts,"cylinder","metal",Vector3(-0.7+i*1.4,1.42+development*0.2,-0.3),Vector3(0.41,2.10+development*0.4,0.41))
				_part(parts,"cylinder","dark",Vector3(-0.7+i*1.4,2.55+development*0.4,-0.3),Vector3(0.51,0.14,0.51))
			_box(parts,"light",0,0.43,0.946,1.6,0.2,0.035)
			_box(parts,"metal",0,0.20,1.35,2.45,0.11,0.55)
		"research":
			_part(parts,"cylinder","stone",Vector3(0,0.11,0),Vector3(2.95,0.22,2.95))
			_part(parts,"cylinder","shell",Vector3(0,0.65,0),Vector3(2.3,0.85,2.3))
			_part(parts,"dome","glass",Vector3(0,1.08,0),Vector3(2.3,0.83+development*0.22,2.3))
			for i: int in 6:
				var angle: float = i*TAU/6.0
				_box(parts,"metal",cos(angle)*1.28,0.15,sin(angle)*1.28,0.12,1.18,0.12)
			_part(parts,"cylinder","metal",Vector3(1.55,1.28,0),Vector3(0.08,2.45,0.08))
			_part(parts,"dome","shell",Vector3(1.55,2.5,0),Vector3(0.6,0.16,0.6))
	return _varied(parts,slot)


static func _varied(parts: Array[Dictionary], slot: Dictionary) -> Array[Dictionary]:
	var rng: RandomNumberGenerator=RandomNumberGenerator.new()
	rng.seed=int(slot.get("seed",11))
	var scale_basis: Basis=Basis.from_scale(Vector3(rng.randf_range(0.94,1.02),rng.randf_range(0.94,1.10),rng.randf_range(0.94,1.02)))
	for part: Dictionary in parts:
		var transform: Transform3D=part["transform"]
		part["transform"]=Transform3D(scale_basis*transform.basis,scale_basis*transform.origin)
	return parts


static func _vael(parts: Array[Dictionary], kind: String, development: int, terrain_kind: String) -> void:
	if kind == "agriculture":
		for i: int in 3:
			var x: float = (i-1)*1.02
			_part(parts,"dome","crop",Vector3(x,0.02,0),Vector3(0.91,0.16,2.7))
			_part(parts,"dome","glass",Vector3(x,0.08,0),Vector3(1.0,0.70,2.85))
		return
	if kind == "energy":
		for i: int in 7:
			var angle: float = i*TAU/7.0
			_part(parts,"dome","solar",Vector3(cos(angle)*1.28,0.16,sin(angle)*1.28),Vector3(0.9,0.26,0.9))
		_part(parts,"dome","shell",Vector3.ZERO,Vector3(0.72,1.2+development*0.35,0.72))
	elif kind == "mining":
		_part(parts,"dome","dark",Vector3(0,-0.1,0),Vector3(1.65,0.20,1.65))
		for i: int in 3:
			var angle: float = i*TAU/3.0
			_part(parts,"arch","shell",Vector3(cos(angle)*0.45,0.05,sin(angle)*0.45),Vector3(2.5,2.5,1.5),Vector3(0,-rad_to_deg(angle),0))
	else:
		for i: int in 3:
			var angle: float = i*TAU/3.0
			var h: float = 1.05+development*0.68 if kind == "habitation" else 1.1+development*0.48
			_part(parts,"dome","shell",Vector3(cos(angle)*0.75,0.04,sin(angle)*0.75),Vector3(1.7,h,1.7))
			_part(parts,"arch","metal",Vector3.ZERO,Vector3(2.6,h*2.0,1.1),Vector3(0,i*60.0,0))
		if kind == "research":
			_part(parts,"dome","glass",Vector3(0,0.65,0),Vector3(1.15,2.05+development*0.25,1.15))
	for i: int in 7:
		var angle: float = i*TAU/7.0
		_part(parts,"sphere","light",Vector3(cos(angle)*1.25,0.42,sin(angle)*1.25),Vector3.ONE*0.11)
