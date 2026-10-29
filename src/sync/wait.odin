package jsync

import "base:intrinsics"

SPIN_COUNT :: 64

wait_while :: proc "contextless" (a: ^u32, expected: u32) {
	for _ in 0..<SPIN_COUNT {
		if intrinsics.atomic_load_explicit(a, .Acquire) != expected {
			return
		}
		intrinsics.cpu_relax()
	}
	for intrinsics.atomic_load_explicit(a, .Acquire) == expected {
		_platform_wait(a, expected)
	}
}

wake_one :: proc "contextless" (a: ^u32) {
	_platform_wake(a, 1)
}

wake_all :: proc "contextless" (a: ^u32) {
	_platform_wake(a, max(u32))
}

wait_until_at_least :: proc "contextless" (a: ^u32, target: u32) {
	for {
		v := intrinsics.atomic_load_explicit(a, .Acquire)
		if v >= target { return }
		wait_while(a, v)
	}
}

bump :: proc "contextless" (a: ^u32) {
	intrinsics.atomic_add_explicit(a, 1, .Release)
	wake_all(a)
}
