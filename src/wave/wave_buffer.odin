package wave

NUM_BUFFERS  :: 20
BUFFER_BYTES :: 2048

Wave_Buffer :: struct {
	state:  u32,
	id:     int,
	len:    int,
	seq:    u32,
	cycles: int,
	data:   [BUFFER_BYTES]u8,
}

init_all :: proc(bufs: ^[NUM_BUFFERS]Wave_Buffer) {
	for &b, i in bufs {
		b = {}
		b.id = i
	}
}

kill_all :: proc "contextless" (bufs: ^[NUM_BUFFERS]Wave_Buffer) {
	for &b in bufs {
		set_state(&b, .Dead)
	}
}

run :: proc(w: ^Wave_Buffer) {
	for {
		s := wait_while_state(w, .Empty)
		if s == .Dead { return }
		set_state(w, .Queued)

		s = wait_while_state(w, .Queued)
		if s == .Dead { return }
		w.cycles += 1
		set_state(w, .Empty)
	}
}
