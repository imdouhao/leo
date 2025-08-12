package texture
import leo "../../lib"
main :: proc() {
	using leo
	vertices := []Vertex {
		{position = {-1.0, 1.0, 0.0}},
		{position = {-1.0, -1.0, 0.0}},
		{position = {1.0, -1.0, 0.0}},
		{position = {1.0, 1.0, 0.0}},
	}
	indices := []int{0, 1, 2, 0, 2, 3}

	mesh := Mesh {
		primitives = {{vertices = vertices, indices = indices}},
	}

	framebuffer := framebuffer_new(512, 512)
	defer framebuffer_free(framebuffer)

	render(framebuffer, &mesh)
	framebuffer_write_png(framebuffer, "texture.png")
}
