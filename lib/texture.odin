package leo
import "core:math"

TextureFormat :: enum {
	RGB = 3,
}

Texture2D :: struct {
	width:  int,
	height: int,
	format: TextureFormat,
	data:   []f32,
}
// reference : https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html#reference-sampler

MagFilterMode :: enum {
	NEAREST = 9728,
	LINEAR  = 9729,
}
MinFilterMode :: enum {
	NEAREST                = 9728,
	LINEAR                 = 9729,
	NEAREST_MIPMAP_NEAREST = 9984,
	LINEAR_MIPMAP_NEAREST  = 9985,
	NEAREST_MIPMAP_LINEAR  = 9986,
	LINEAR_MIPMAP_LINEAR   = 9987,
}

WrapMode :: enum {
	CLAMP_TO_EDGE   = 33071,
	MIRRORED_REPEAT = 33648,
	REPEAT          = 10497,
}


Sampler2D :: struct {
	min_filter: MinFilterMode,
	mag_filter: MagFilterMode,
	wrap_s:     WrapMode,
	wrap_t:     WrapMode,
}

texture_2d_sample :: proc(texture: Texture2D, sampler: Sampler2D, uv: Vec2) -> Vec3 {

	// TODO: currently only neareast sampling is implemented
	x := int(math.round((uv.x + 0.5) * f32(texture.width)))
	y := int(math.round((uv.y + 0.5) * f32(texture.height)))
	index := (y * texture.width + x) * int(texture.format)
	res: Vec3
	for &v, i in res {
		v = texture.data[index + i]
	}
	return res
}
