package renderer
import "core:math"
import "core:fmt"
import "core:math/linalg"
import "core:mem"
import stb_image "vendor:stb/image"
Vec2 :: linalg.Vector2f32
Vec3 :: linalg.Vector3f32
Vec4 :: linalg.Vector4f32
Mat4 :: linalg.Matrix4x4f32
Mat3 :: linalg.Matrix3x3f32

Plane :: struct {
    normal: Vec3,
    distance: f32,
}

plane_from_point_and_normal :: proc(p: Vec3, n: Vec3) -> Plane {
    distance := linalg.dot(p, n)
    return {
        normal = n,
        distance = distance,
    }
}

// Frustum :: struct {
//     top: Plane,
//     bottom: Plane,
//     right: Plane,
//     left: Plane,
//     far: Plane,
//     near: Plane
// }

// frustum_new :: proc(eye: Vec3, target: Vec3, up: Vec3, fov_in_radians: f32, aspect: f32, near: f32, far: f32, allocator := context.allocator) -> ^Frustum {
//     frustum := new(Frustum)
//     half_v_side := far * math.tan(fov_in_radians * 0.5)
//     half_h_side := half_v_side * aspect
//     front_dir := linalg.normalize(target-eye)
//     far_vec := front_dir * far
//     near_vec := front_dir * near
//     frustum.near = plane_from_point_and_normal(eye + near_vec, front_dir)
//     frustum.far = plane_from_point_and_normal(eye + far_vec, -front_dir)
//     frustum.right = plane_from_point_and_normal(eye, linalg.cross(far_vec - ))
// }


Vertex :: struct {
    position: Vec3,
    normal: Vec3,
    uv: Vec2,
}

Primitive:: struct {
    vertices: []Vertex,
    indices: []u16,
}

Mesh :: struct {

}


Framebuffer :: struct {
    width: i32,
    height: i32,
    channels: i32,
    buffer: []u8,
    depth: []f32,
}

framebuffer_new :: proc(width: i32, height: i32, channels: i32 = 3, allocator := context.allocator) -> ^Framebuffer {
    framebuffer := new(Framebuffer, allocator)
    framebuffer.width = width
    framebuffer.height = height
    framebuffer.channels = channels
    framebuffer.buffer = make([]u8, width * height * channels)
    framebuffer.depth = make([]f32, width * height)
    for &v in framebuffer.depth {
        v = 1.0
    }
    return framebuffer
}

framebuffer_free :: proc(framebuffer: ^Framebuffer) {
    delete(framebuffer.buffer)
    free(framebuffer)
}

// TODO: currently assuming the color passed in by the caller is of the right channel
framebuffer_set_pixel:: proc(framebuffer: ^Framebuffer, x: i32, y: i32, color: []u8) {
    pos := y * framebuffer.width * framebuffer.channels + x * framebuffer.channels
    mem.copy(raw_data(framebuffer.buffer[pos:]), raw_data(color), int(framebuffer.channels))
}

framebuffer_write_png :: proc(framebuffer: ^Framebuffer, filename: cstring) {
    stb_image.write_png(filename, framebuffer.width, framebuffer.height, framebuffer.channels, raw_data(framebuffer.buffer), framebuffer.width * framebuffer.channels)
}



RenderContext :: struct {
    framebuffer: ^Framebuffer
}


should_clip :: proc(clip_coords: [3]Vec4) -> bool {
    is_point_inside :: proc(v: Vec4) -> bool {
        for i in 0..<3 {
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


render :: proc(framebuffer: ^Framebuffer, primitive: ^Primitive) {
    aspect := f32(framebuffer.width) / f32(framebuffer.height)
    proj := linalg.matrix4_perspective_f32(linalg.to_radians(f32(60.0)), aspect, 0.001, 1000.0)
    view := linalg.matrix4_look_at_f32({0.0, 0.0, 10.0}, {0.0, 0.0, 0.0}, {0.0, 1.0, 0.0})
    model := linalg.MATRIX4F32_IDENTITY
    mvp := linalg.mul(linalg.mul(proj, view), model)
    for i := 0; i < len(primitive.indices); i += 3 {
        clip_positions : [3]Vec4
        for index in 0..<3 {
            p := primitive.vertices[i + index].position
            p_as_vec4 :Vec4 = {p.x, p.y, p.z, 1.0}
            clip_positions[index] = linalg.mul(mvp, p_as_vec4)
        }

        // clipping
        // TODO: MAYBE MAKE SURE W COMPONENT IS NOT NEAR ZERO?
        // discard triangle that are out of view frustrum

        if should_clip(clip_positions) {
            continue;
        }

        // pespective divide
        // and view  port transform
        for index in 0..<3 {
         clip_positions[index].w = 1.0 / clip_positions[index].w
         clip_positions[index].xyz = clip_positions[index].xyz * clip_positions[index].w
         
        }
        
        screen_positions : [3][2]f32
        // viewport transform
        width := framebuffer.width
        height := framebuffer.height
        for index in 0..<3 {
            screen_positions[index].x = (clip_positions[index].x + 1.0) * f32(width-1) * 0.5
            screen_positions[index].y = (1.0 - (clip_positions[index].y)) * f32(height-1) * 0.5
        }

        min_x := clamp(min(screen_positions[0].x, screen_positions[1].x, screen_positions[2].x), 0, f32(width-1))
        min_y := clamp(min(screen_positions[0].y, screen_positions[1].y, screen_positions[2].y), 0, f32(height-1))
        max_x := clamp(max(screen_positions[0].x, screen_positions[1].x, screen_positions[2].x), 0, f32(width-1))
        max_y := clamp(max(screen_positions[0].y, screen_positions[1].y, screen_positions[2].y), 0, f32(height-1))

        for x := i32(min_x); x <= i32(max_x) ; x+=1 {
            for y := i32(min_y); y <= i32(max_y); y += 1 {
                p := Vec2{f32(x), f32(y)}
                weights := barycentric(screen_positions[0], screen_positions[1], screen_positions[2], p)
                if weights.x < 0.0 || weights.x > 1.0 || weights.y < 0.0 || weights.y > 1.0 || weights.z < 0.0 || weights.z > 1.0 {
                    continue;
                } else {
                    depth := weights.x * clip_positions[0].z  + weights.y * clip_positions[1].z + weights.z * clip_positions[2].z
                   
                    if depth < 0.0 || depth > 1.0 {
                        continue;
                    }

                    w := weights.x * clip_positions[0].w + weights.y * clip_positions[1].w + weights.z * clip_positions[2].w
                    perspective_weights := weights * Vec3{clip_positions[0].w, clip_positions[1].w, clip_positions[2].w} * 1.0 / w

                    color := Vec3{1.0, 0.0, 0.0} * perspective_weights.x + Vec3{0.0, 1.0, 0.0} * perspective_weights.y + Vec3{0.0, 0.0, 1.0} * perspective_weights.z

                    r := clamp(u8(color.r * 255), 0, 255)
                    g := clamp(u8(color.g * 255), 0, 255)
                    b := clamp(u8(color.b * 255), 0, 255)
                    
                    fmt.println(depth)
                    index := width * y + x;
                    if depth < framebuffer.depth[index] {
                        framebuffer_set_pixel(framebuffer, x, y, {r, g, b})
                        framebuffer.depth[index] = depth
                    }
                }
            }
        }
    }
}

main :: proc() {
    primitive : Primitive
    primitive.vertices = make([]Vertex, 3)
    defer delete(primitive.vertices)
    primitive.indices = make([]u16, 3)
    defer delete(primitive.indices)
    primitive.vertices[0] = Vertex {
        position = {0.0, 0.5, 8.0},
    }
    primitive.vertices[1] = Vertex {
        position = {-0.5, -0.5, 8.0},
    }

    primitive.vertices[2] = Vertex {
        position = {0.5, -0.5, 8.0}
    }
    primitive.indices[0] = 0
    primitive.indices[1] = 1
    primitive.indices[2] = 2

    framebuffer := framebuffer_new(512, 512, 3)
    defer framebuffer_free(framebuffer)

    render(framebuffer, &primitive)
    framebuffer_write_png(framebuffer, "test.png")
}