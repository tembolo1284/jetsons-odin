package spsc

import "base:intrinsics"

Padded_Index :: struct #align(64) {
	v: u32,
}

Ring :: struct($T: typeid, $N: int) where (N & (N - 1)) == 0, N > 0 {
	head: Padded_Index,
	tail: Padded_Index,
	buf:  [N]T,
}

Producer :: struct($T: typeid, $N: int) {
	ring: ^Ring(T, N),
}

Consumer :: struct($T: typeid, $N: int) {
	ring: ^Ring(T, N),
}

split :: proc(r: ^Ring($T, $N)) -> (Producer(T, N), Consumer(T, N)) {
	return Producer(T, N){r}, Consumer(T, N){r}
}

push :: proc "contextless" (p: ^Producer($T, $N), v: T) -> bool {
	r := p.ring
	tail := intrinsics.atomic_load_explicit(&r.tail.v, .Relaxed)
	head := intrinsics.atomic_load_explicit(&r.head.v, .Acquire)
	if tail - head == u32(N) {
		return false
	}
	r.buf[tail & u32(N - 1)] = v
	intrinsics.atomic_store_explicit(&r.tail.v, tail + 1, .Release)
	return true
}

pop :: proc "contextless" (c: ^Consumer($T, $N)) -> (v: T, ok: bool) {
	r := c.ring
	head := intrinsics.atomic_load_explicit(&r.head.v, .Relaxed)
	tail := intrinsics.atomic_load_explicit(&r.tail.v, .Acquire)
	if tail == head {
		return
	}
	v = r.buf[head & u32(N - 1)]
	intrinsics.atomic_store_explicit(&r.head.v, head + 1, .Release)
	return v, true
}

len :: proc "contextless" (r: ^Ring($T, $N)) -> int {
	tail := intrinsics.atomic_load_explicit(&r.tail.v, .Acquire)
	head := intrinsics.atomic_load_explicit(&r.head.v, .Acquire)
	return int(tail - head)
}
