package leo
import "core:fmt"
import "vendor:cgltf"

Vertex :: struct {
	position: Vec3,
	normal:   Vec3,
	uv:       Vec2,
}

Primitive :: struct {
	vertices: []Vertex,
	indices:  []int,
}

Mesh :: struct {
	primitives: []Primitive,
}

mesh_free :: proc(mesh: ^Mesh) {
	for primitive in mesh.primitives {
		delete(primitive.vertices)
		delete(primitive.indices)

	}
	delete(mesh.primitives)
}

load_mesh :: proc(filename: cstring) -> (^Mesh, bool) {
	gltf_data, success := cgltf.parse_file(cgltf.options{}, filename)
	if success != .success {
		fmt.printf("failed to load file%s\n", filename)
		return nil, false
	}
	success = cgltf.load_buffers(cgltf.options{}, gltf_data, filename)
	if success != .success {
		fmt.println("failed to load buffers")
		return nil, false
	}
	out_mesh := new(Mesh)

	gltf_mesh := gltf_data.meshes[0]

	out_mesh.primitives = make([]Primitive, len(gltf_mesh.primitives))
	for primitive, primitive_index in gltf_mesh.primitives {
		count := primitive.attributes[0].data.count
		out_primitive := &(out_mesh.primitives[primitive_index])
		out_primitive.vertices = make([]Vertex, count)
		for attribute in primitive.attributes {
			accessor := attribute.data
			num_floats := cgltf.accessor_unpack_floats(attribute.data, nil, 0)
			float_array := make([]f32, num_floats)
			defer delete(float_array)
			res := cgltf.accessor_unpack_floats(attribute.data, &float_array[0], num_floats)
			switch attribute.name {
			case "POSITION":
				assert(accessor.type == .vec3, "only triangle is supported")
				for i in 0 ..< count {
					out_primitive.vertices[i].position = {
						float_array[3 * i],
						float_array[3 * i + 1],
						float_array[3 * i + 2],
					}
				}
			case "NORMAL":
				assert(accessor.type == .vec3, "normal must be of type vec3")
				for i in 0 ..< count {
					out_primitive.vertices[i].normal = {
						float_array[3 * i],
						float_array[3 * i + 1],
						float_array[3 * i + 2],
					}
				}
			case "TEXCOORD_0":
				assert(accessor.type == .vec2, "uv must be of type vec2")
				for i in 0 ..< count {
					out_primitive.vertices[i].uv = {float_array[2 * i], float_array[2 * i + 1]}
				}
			case:
				fmt.println("attribute %s is currently unsupported", attribute.name)
			}

			index_accessor := primitive.indices
			out_primitive.indices = make([]int, index_accessor.count)
			indices := make([]u16, index_accessor.count)
			res = cgltf.accessor_unpack_indices(
				index_accessor,
				&(indices[0]),
				2,
				index_accessor.count,
			)
			for v, i in indices {
				out_primitive.indices[i] = int(v)
			}
			assert(res == index_accessor.count, "failed to extract the right amount of indices")
		}
	}
	return out_mesh, true
}
