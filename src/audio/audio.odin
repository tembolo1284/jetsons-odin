package audio

import "base:intrinsics"
import jsync "../sync"
import "../wave"

SAMPLE_RATE     :: 22050
CHANNELS        :: 2
BYTES_PER_FRAME :: 4

Engine :: struct {
	bufs:            ^[wave.NUM_BUFFERS]wave.Wave_Buffer,
	cursor:          int,
	offset:          int,
	started:         bool,
	underrun_frames: u64,
	frames_rendered: u64,
	final_seq:       u32,
	drained:         u32,
}

init :: proc(e: ^Engine, bufs: ^[wave.NUM_BUFFERS]wave.Wave_Buffer) {
	e^ = {}
	e.bufs = bufs
}

set_final_seq :: proc "contextless" (e: ^Engine, seq_plus_one: u32) {
	intrinsics.atomic_store_explicit(&e.final_seq, seq_plus_one, .Release)
}

is_drained :: proc "contextless" (e: ^Engine) -> bool {
	return intrinsics.atomic_load_explicit(&e.drained, .Acquire) != 0
}

wait_drained :: proc "contextless" (e: ^Engine) {
	jsync.wait_while(&e.drained, 0)
}

force_drained :: proc "contextless" (e: ^Engine) {
	intrinsics.atomic_store_explicit(&e.drained, 1, .Release)
	jsync.wake_all(&e.drained)
}

render :: proc "contextless" (e: ^Engine, out: []u8) {
	written := 0
	for written < len(out) {
		if is_drained(e) {
			intrinsics.mem_zero(&out[written], len(out) - written)
			written = len(out)
			break
		}
		wb := &e.bufs[e.cursor]
		if wave.get_state(wb) != .Queued {
			n := len(out) - written
			intrinsics.mem_zero(&out[written], n)
			if e.started {
				e.underrun_frames += u64(n / BYTES_PER_FRAME)
			}
			written = len(out)
			break
		}
		e.started = true
		n := min(wb.len - e.offset, len(out) - written)
		intrinsics.mem_copy_non_overlapping(&out[written], &wb.data[e.offset], n)
		written += n
		e.offset += n
		if e.offset >= wb.len {
			e.offset = 0
			last := wb.seq + 1 == intrinsics.atomic_load_explicit(&e.final_seq, .Acquire)
			wave.set_state(wb, .Done)
			e.cursor = (e.cursor + 1) % wave.NUM_BUFFERS
			if last {
				force_drained(e)
			}
		}
	}
	e.frames_rendered += u64(len(out) / BYTES_PER_FRAME)
}
