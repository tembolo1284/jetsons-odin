package jsync

import "base:intrinsics"

Kill_Signal :: struct {
	flag: u32,
}

kill_requested :: proc "contextless" (k: ^Kill_Signal) -> bool {
	return intrinsics.atomic_load_explicit(&k.flag, .Acquire) != 0
}

request_kill :: proc "contextless" (k: ^Kill_Signal) {
	intrinsics.atomic_store_explicit(&k.flag, 1, .Release)
	wake_all(&k.flag)
}

wait_for_kill :: proc "contextless" (k: ^Kill_Signal) {
	wait_while(&k.flag, 0)
}
