package audio

import "base:intrinsics"
import "core:time"

NULL_BLOCK_FRAMES :: 512

Null_Sink :: struct {
	engine: ^Engine,
	speed:  f64,
	stop:   u32,
	block:  [NULL_BLOCK_FRAMES * BYTES_PER_FRAME]u8,
}

null_init :: proc(s: ^Null_Sink, e: ^Engine, speed: f64) {
	s^ = {}
	s.engine = e
	s.speed = speed if speed > 0 else 1
}

null_stop :: proc "contextless" (s: ^Null_Sink) {
	intrinsics.atomic_store_explicit(&s.stop, 1, .Release)
}

null_run :: proc(s: ^Null_Sink) {
	period := time.Duration(f64(NULL_BLOCK_FRAMES) / f64(SAMPLE_RATE) * 1e9 / s.speed)
	start := time.tick_now()
	k: i64 = 0
	for intrinsics.atomic_load_explicit(&s.stop, .Acquire) == 0 && !is_drained(s.engine) {
		render(s.engine, s.block[:])
		k += 1
		remaining := time.Duration(k) * period - time.tick_since(start)
		if remaining > 0 {
			time.sleep(remaining)
		}
	}
}
