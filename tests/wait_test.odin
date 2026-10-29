package tests

import "base:intrinsics"
import "core:testing"
import "core:thread"
import "core:time"
import jsync "../src/sync"

Waiter :: struct {
	flag:  u32,
	woke:  bool,
}

waiter_proc :: proc(w: ^Waiter) {
	jsync.wait_while(&w.flag, 0)
	w.woke = true
}

@(test)
wait_no_lost_wakeup :: proc(t: ^testing.T) {
	w: Waiter
	th := thread.create_and_start_with_poly_data(&w, waiter_proc)
	time.sleep(20 * time.Millisecond)
	intrinsics.atomic_store_explicit(&w.flag, 1, .Release)
	jsync.wake_all(&w.flag)
	thread.join(th)
	thread.destroy(th)
	testing.expect(t, w.woke)
}

@(test)
wait_returns_immediately_if_changed :: proc(t: ^testing.T) {
	flag: u32 = 7
	jsync.wait_while(&flag, 0)
	testing.expect_value(t, flag, 7)
}

Pong :: struct {
	flag:   u32,
	rounds: int,
	seen:   int,
}

ponger :: proc(p: ^Pong) {
	for _ in 0..<p.rounds {
		jsync.wait_while(&p.flag, 0)
		p.seen += 1
		intrinsics.atomic_store_explicit(&p.flag, 0, .Release)
		jsync.wake_one(&p.flag)
	}
}

@(test)
wait_ping_pong :: proc(t: ^testing.T) {
	p := Pong{rounds = 10_000}
	th := thread.create_and_start_with_poly_data(&p, ponger)
	for _ in 0..<p.rounds {
		intrinsics.atomic_store_explicit(&p.flag, 1, .Release)
		jsync.wake_one(&p.flag)
		jsync.wait_while(&p.flag, 1)
	}
	thread.join(th)
	thread.destroy(th)
	testing.expect_value(t, p.seen, p.rounds)
}

Broadcast :: struct {
	gate:   u32,
	count:  u32,
}

broadcast_waiter :: proc(b: ^Broadcast) {
	jsync.wait_while(&b.gate, 0)
	intrinsics.atomic_add_explicit(&b.count, 1, .Acq_Rel)
}

@(test)
wait_wake_all_releases_everyone :: proc(t: ^testing.T) {
	b: Broadcast
	ths: [8]^thread.Thread
	for &th in ths {
		th = thread.create_and_start_with_poly_data(&b, broadcast_waiter)
	}
	time.sleep(20 * time.Millisecond)
	intrinsics.atomic_store_explicit(&b.gate, 1, .Release)
	jsync.wake_all(&b.gate)
	for th in ths {
		thread.join(th)
		thread.destroy(th)
	}
	testing.expect_value(t, intrinsics.atomic_load_explicit(&b.count, .Acquire), u32(8))
}
