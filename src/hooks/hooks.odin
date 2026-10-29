package hooks

import "core:time"
import "../crc32"

MAX_TRANSFERS :: 64

Transfer :: struct {
	buff: rawptr,
	size: int,
	crc:  u32,
	t:    time.Tick,
}

Hooks :: struct {
	file_buff: rawptr,
	coord_a:   rawptr,
	coord_b:   rawptr,
	start:     time.Tick,
	transfers: [MAX_TRANSFERS]Transfer,
	count:     int,
}

init :: proc(h: ^Hooks) {
	h^ = {}
	h.start = time.tick_now()
}

file_buffer_info :: proc(h: ^Hooks, p: rawptr) {
	if h == nil { return }
	h.file_buff = p
}

coord_a_buffer_info :: proc(h: ^Hooks, p: rawptr) {
	if h == nil { return }
	h.coord_a = p
}

coord_b_buffer_info :: proc(h: ^Hooks, p: rawptr) {
	if h == nil { return }
	h.coord_b = p
}

data_transfer :: proc(h: ^Hooks, buff: rawptr, size: int) {
	if h == nil { return }
	if h.count >= MAX_TRANSFERS { return }
	bytes := (cast([^]u8)buff)[:size]
	h.transfers[h.count] = Transfer{
		buff = buff,
		size = size,
		crc  = crc32.compute(bytes),
		t    = time.tick_now(),
	}
	h.count += 1
}

elapsed_ms :: proc(h: ^Hooks, i: int) -> f64 {
	return time.duration_milliseconds(time.tick_diff(h.start, h.transfers[i].t))
}
