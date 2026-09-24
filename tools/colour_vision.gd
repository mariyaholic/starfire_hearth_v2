class_name ColourVision
extends RefCounted
## Colour-vision deficiency simulation for the screenshot tour and palette tests (§6.9).
## Machado, Oliveira and Fernandes (2009) matrix for deuteranopia at full severity, applied in
## linear RGB.

const DEUTERANOPIA: Array[float] = [
	0.367322, 0.860646, -0.227968,
	0.280085, 0.672501, 0.047413,
	-0.011820, 0.042940, 0.968881,
]


static func to_linear(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)


static func to_srgb(v: float) -> float:
	v = clampf(v, 0.0, 1.0)
	return v * 12.92 if v <= 0.0031308 else 1.055 * pow(v, 1.0 / 2.4) - 0.055


static func simulate(c: Color) -> Color:
	var r: float = to_linear(c.r)
	var g: float = to_linear(c.g)
	var b: float = to_linear(c.b)
	var m: Array[float] = DEUTERANOPIA
	return Color(
		to_srgb(m[0] * r + m[1] * g + m[2] * b),
		to_srgb(m[3] * r + m[4] * g + m[5] * b),
		to_srgb(m[6] * r + m[7] * g + m[8] * b),
		c.a)


## A deuteranopia-simulated copy of `img`, downscaled by `shrink` first to keep it quick.
static func deuteranopia(img: Image, shrink: int = 1) -> Image:
	var src: Image = img.duplicate()
	if shrink > 1:
		src.resize(src.get_width() / shrink, src.get_height() / shrink, Image.INTERPOLATE_BILINEAR)
	src.convert(Image.FORMAT_RGB8)
	var lut_lin: PackedFloat32Array = PackedFloat32Array()
	lut_lin.resize(256)
	for i in 256:
		lut_lin[i] = to_linear(i / 255.0)
	var lut_out: PackedByteArray = PackedByteArray()
	lut_out.resize(4096)
	for i in 4096:
		lut_out[i] = int(round(to_srgb(i / 4095.0) * 255.0))
	var data: PackedByteArray = src.get_data()
	var m: Array[float] = DEUTERANOPIA
	var i: int = 0
	var n: int = data.size()
	while i < n:
		var r: float = lut_lin[data[i]]
		var g: float = lut_lin[data[i + 1]]
		var b: float = lut_lin[data[i + 2]]
		data[i] = lut_out[clampi(int((m[0] * r + m[1] * g + m[2] * b) * 4095.0), 0, 4095)]
		data[i + 1] = lut_out[clampi(int((m[3] * r + m[4] * g + m[5] * b) * 4095.0), 0, 4095)]
		data[i + 2] = lut_out[clampi(int((m[6] * r + m[7] * g + m[8] * b) * 4095.0), 0, 4095)]
		i += 3
	return Image.create_from_data(src.get_width(), src.get_height(), false, Image.FORMAT_RGB8, data)
