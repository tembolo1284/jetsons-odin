package crc32

@(private) table:  [0x100]u32
@(private) wtable: [0x100 * 4]u32

@(private)
for_byte :: proc "contextless" (r0: u32) -> u32 {
	r := r0
	for _ in 0..<8 {
		r = (0 if r & 1 != 0 else 0xEDB88320) ~ (r >> 1)
	}
	return r ~ 0xFF000000
}

@(init)
init_tables :: proc() {
	for i in 0..<0x100 {
		table[i] = for_byte(u32(i))
	}
	for k in 0..<4 {
		for i in 0..<0x100 {
			w: u32 = 0
			for j in 0..<4 {
				w = table[u8(w ~ u32(i) if j == k else w)] ~ (w >> 8)
			}
			wtable[(k << 8) + i] = w ~ (wtable[0] if k != 0 else 0)
		}
	}
}

compute :: proc "contextless" (data: []u8) -> u32 {
	crc: u32 = 0
	n_accum := len(data) / 4
	for i in 0..<n_accum {
		b := i * 4
		word := u32(data[b]) | u32(data[b+1]) << 8 | u32(data[b+2]) << 16 | u32(data[b+3]) << 24
		a := crc ~ word
		crc = 0
		for j in 0..<4 {
			crc ~= wtable[(j << 8) + int(u8(a >> (8 * uint(j))))]
		}
	}
	for i in n_accum * 4..<len(data) {
		crc = table[u8(crc) ~ data[i]] ~ (crc >> 8)
	}
	return crc
}
