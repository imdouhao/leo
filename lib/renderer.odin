package leo
import "core:fmt"
import "core:math"
import "core:math/linalg"

RenderState :: struct {
	mesh:            ^Mesh,
	uniform:         Uniform,
	framebuffer:     ^Framebuffer,
	vertex_shader:   proc(vertex: Vertex, uniform: Uniform) -> Vec4,
	fragment_shader: proc(frag_coord: Vec4) -> Vec4,
}


Uniform :: struct {
	vp:    Mat4,
	model: Mat4,
}

simple_vertex_shader :: proc(vertex: Vertex, uniform: Uniform) -> Vec4 {
	position_as_vec4 := Vec4{vertex.position.x, vertex.position.y, vertex.position.z, 1.0}
	return linalg.mul(linalg.mul(uniform.vp, uniform.model), position_as_vec4)
}


simple_fragment_shader :: proc(frag_coord: Vec4) -> Vec4 {
	return Vec4{1.0, 0.0, 0.0, 1.0}
}


should_clip :: proc(clip_coords: [3]Vec4) -> bool {
	is_point_inside :: proc(v: Vec4) -> bool {
		for i in 0 ..< 3 {
			if v[i] < -v.w || v[i] > v.w {
				return false
			}
		}
		return true
	}
	for v in clip_coords {
		if is_point_inside(v) {
			return false
		}
	}
	return true
}

barycentric :: proc(a, b, c, p: Vec2) -> Vec3 {
	ac := c - a
	ab := b - a
	ap := p - a
	pc := c - p
	pb := b - p

	area := (ac.x * ab.y - ac.y * ab.x)

	if area == 0.0 {
		return Vec3{0.0, 0.0, 0.0}
	}

	alpha := (pc.x * pb.y - pc.y * pb.x) / area
	beta := (ac.x * ap.y - ac.y * ap.x) / area
	gamma := 1.0 - alpha - beta

	return Vec3{alpha, beta, gamma}
}

get_perspective_correct_interpolate_weights :: proc(bary: Vec3, one_over_w: Vec3) -> Vec3 {
	numerator := bary * one_over_w
	denom := 1.0 / (numerator.x + numerator.y + numerator.z)
	return numerator * denom
}


render :: proc(render_state: RenderState) {
	framebuffer := render_state.framebuffer
	mesh := render_state.mesh
	width := framebuffer.width
	height := framebuffer.height
	uniform := render_state.uniform
	vertex_shader := render_state.vertex_shader
	if vertex_shader == nil {
		vertex_shader = simple_vertex_shader
	}
	fragment_shader := render_state.fragment_shader
	if fragment_shader == nil {
		fragment_shader = simple_fragment_shader
	}
	for primitive in mesh.primitives {
		for i := 0; i < len(primitive.indices); i += 3 {
			clip_positions: [3]Vec4
			for index in 0 ..< 3 {
				clip_positions[index] = vertex_shader(
					primitive.vertices[primitive.indices[i + index]],
					uniform,
				)
			}


			// clipping
			// TODO: MAYBE MAKE SURE W COMPONENT IS NOT NEAR ZERO?
			// discard triangle that are out of view frustrum

			if should_clip(clip_positions) {
				continue
			}

			// pespective divide
			// and view  port transform
			for index in 0 ..< 3 {
				clip_positions[index].w = 1.0 / clip_positions[index].w
				clip_positions[index].xyz = clip_positions[index].xyz * clip_positions[index].w

			}

			screen_positions: [3][2]f32
			// viewport transform

			for index in 0 ..< 3 {
				screen_positions[index].x = (clip_positions[index].x + 1.0) * f32(width - 1) * 0.5
				screen_positions[index].y =
					(1.0 - (clip_positions[index].y)) * f32(height - 1) * 0.5
			}

			// back face culling
			ab := screen_positions[1] - screen_positions[0]
			ac := screen_positions[2] - screen_positions[0]
			if ab.x * ac.y - ac.x * ab.y > 0.0 {
				continue
			}


			min_x := clamp(
				min(screen_positions[0].x, screen_positions[1].x, screen_positions[2].x),
				0,
				f32(width - 1),
			)
			min_y := clamp(
				min(screen_positions[0].y, screen_positions[1].y, screen_positions[2].y),
				0,
				f32(height - 1),
			)
			max_x := clamp(
				max(screen_positions[0].x, screen_positions[1].x, screen_positions[2].x),
				0,
				f32(width - 1),
			)
			max_y := clamp(
				max(screen_positions[0].y, screen_positions[1].y, screen_positions[2].y),
				0,
				f32(height - 1),
			)


			for x := i32(min_x); x <= i32(max_x); x += 1 {
				for y := i32(min_y); y <= i32(max_y); y += 1 {
					p := Vec2{f32(x) + 0.5, f32(y) + 0.5}
					weights := barycentric(
						screen_positions[0],
						screen_positions[1],
						screen_positions[2],
						p,
					)

					// fmt.println(Vec3{alpha, beta, gamm   a})
					// fmt.println(weights)

					if weights.x < 0.0 ||
					   weights.x > 1.0 ||
					   weights.y < 0.0 ||
					   weights.y > 1.0 ||
					   weights.z < 0.0 ||
					   weights.z > 1.0 {
						continue
					} else {
						depth :=
							weights.x * clip_positions[0].z +
							weights.y * clip_positions[1].z +
							weights.z * clip_positions[2].z

						w :=
							weights.x +
							clip_positions[0].w +
							weights.y * clip_positions[1].w +
							weights.z * clip_positions[2].w

						if depth < 0.0 || depth > 1.0 {
							continue
						}

						perspective_correct_weights := get_perspective_correct_interpolate_weights(
							weights,
							{clip_positions[0].w, clip_positions[1].w, clip_positions[2].w},
						)


						frag_coords: Vec4 = {p.x, p.y, depth, w}
						color := fragment_shader(frag_coords)

						r := u8(math.floor(color.r * 255.99))
						g := u8(math.floor(color.g * 255.99))
						b := u8(math.floor(color.b * 255.99))

						// fmt.println(depth)
						index := width * y + x
						if depth < framebuffer.depth[index] {
							framebuffer_set_pixel(framebuffer, x, y, {r, g, b})
							framebuffer.depth[index] = depth
						}
					}
				}
			}
		}
	}
}
