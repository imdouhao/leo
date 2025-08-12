package model

import leo "../../lib"
import "core:fmt"
import "core:math/linalg"


main :: proc() {
	// primitive: Primitive

	// vertices := []Vertex {
	// 	{position = {0.0, 0.5, 0.0}},
	// 	{position = {-0.5, -0.5, 0.0}},
	// 	{position = {0.5, -0.5, 0.0}},
	// }

	// indices := []int{0, 1, 2}

	// primitive.indices = indices
	// primitive.vertices = vertices

	using leo
	mesh, ok := load_mesh("assets/DamagedHelmet/glTF/DamagedHelmet.gltf")
	if !ok {
		panic("failed to load mesh")
	}
	defer mesh_free(mesh)

	fmt.println(len(mesh.primitives[0].indices))


	framebuffer := framebuffer_new(512, 512, 3)
	defer framebuffer_free(framebuffer)

	aspect := f32(framebuffer.width) / f32(framebuffer.height)
	proj := linalg.matrix4_perspective_f32(linalg.to_radians(f32(90.0)), aspect, 0.001, 1000.0)
	view := linalg.matrix4_look_at_f32({0.0, 0.0, 2.0}, {0.0, 0.0, 0.0}, {0.0, 1.0, 0.0})
	model := linalg.MATRIX4F32_IDENTITY
	uniform := Uniform {
		vp    = linalg.mul(proj, view),
		model = model,
	}

	render({mesh = mesh, framebuffer = framebuffer, uniform = uniform})
	framebuffer_write_png(framebuffer, "model.png")
}
