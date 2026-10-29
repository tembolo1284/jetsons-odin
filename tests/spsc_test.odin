package tests

import "base:intrinsics"
import "core:testing"
import "core:thread"
import spsc "../src/spsc"

@(test)
spsc_single_thread :: proc(t: ^testing.T) {
	r: spsc.Ring(int, 8)
	p, c := spsc.split(&r)

	for i in 0..<8 {
		testing.expect(t, spsc.push(&p, i))
	}
	testing.expect(t, !spsc.push(&p, 99))
	testing.expect_value(t, spsc.len(&r), 8)

	for i in 0..<8 {
		v, ok := spsc.pop(&c)
		testing.expect(t, ok)
		testing.expect_value(t, v, i)
	}
	_, ok := spsc.pop(&c)
	testing.expect(t, !ok)
	testing.expect_value(t, spsc.len(&r), 0)
}

@(test)
spsc_index_wraparound :: proc(t: ^testing.T) {
	r: spsc.Ring(int, 4)
	r.head.v = max(u32) - 2
	r.tail.v = max(u32) - 2
	p, c := spsc.split(&r)

	for i in 0..<4 {
		testing.expect(t, spsc.push(&p, i))
	}
	testing.expect(t, !spsc.push(&p, 42))
	for i in 0..<4 {
		v, ok := spsc.pop(&c)
		testing.expect(t, ok)
		testing.expect_value(t, v, i)
	}
	testing.expect_value(t, spsc.len(&r), 0)
}

Stress :: struct {
	c:     spsc.Consumer(u64, 1024),
	count: int,
	sum:   u64,
	ok:    bool,
}

stress_consumer :: proc(s: ^Stress) {
	expect: u64 = 0
	s.ok = true
	for expect < u64(s.count) {
		v, got := spsc.pop(&s.c)
		if !got {
			intrinsics.cpu_relax()
			continue
		}
		if v != expect {
			s.ok = false
			return
		}
		s.sum += v
		expect += 1
	}
}

@(test)
spsc_two_thread_stress :: proc(t: ^testing.T) {
	N :: 1_000_000
	r: spsc.Ring(u64, 1024)
	p, c := spsc.split(&r)
	s := Stress{c = c, count = N}

	th := thread.create_and_start_with_poly_data(&s, stress_consumer)
	for i in 0..<N {
		for !spsc.push(&p, u64(i)) {
			intrinsics.cpu_relax()
		}
	}
	thread.join(th)
	thread.destroy(th)

	testing.expect(t, s.ok)
	testing.expect_value(t, s.sum, u64(N) * u64(N - 1) / 2)
}
