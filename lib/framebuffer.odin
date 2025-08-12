package leo
import "core:mem"

import stb_image "vendor:stb/image"

Framebuffer :: struct {
	width:    i32,
	height:   i32,
	channels: i32,
	buffer:   []u8,
	depth:    []f32,
}

framebuffer_new :: proc(
	width: i32,
	height: i32,
	channels: i32 = 3,
	allocator := context.allocator,
) -> ^Framebuffer {
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
framebuffer_set_pixel :: proc(framebuffer: ^Framebuffer, x: i32, y: i32, color: []u8) {
	pos := y * framebuffer.width * framebuffer.channels + x * framebuffer.channels
	mem.copy(raw_data(framebuffer.buffer[pos:]), raw_data(color), int(framebuffer.channels))
}

framebuffer_write_png :: proc(framebuffer: ^Framebuffer, filename: cstring) {
	stb_image.write_png(
		filename,
		framebuffer.width,
		framebuffer.height,
		framebuffer.channels,
		raw_data(framebuffer.buffer),
		framebuffer.width * framebuffer.channels,
	)
}
