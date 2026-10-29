package wave

import "base:intrinsics"
import jsync "../sync"

State :: enum u32 {
	Empty  = 0,
	Filled = 1,
	Queued = 2,
	Done   = 3,
	Dead   = 4,
}

get_state :: proc "contextless" (w: ^Wave_Buffer) -> State {
	return State(intrinsics.atomic_load_explicit(&w.state, .Acquire))
}

set_state :: proc "contextless" (w: ^Wave_Buffer, s: State) {
	intrinsics.atomic_store_explicit(&w.state, u32(s), .Release)
	jsync.wake_all(&w.state)
}

wait_while_state :: proc "contextless" (w: ^Wave_Buffer, s: State) -> State {
	jsync.wait_while(&w.state, u32(s))
	return get_state(w)
}

wait_until_empty :: proc "contextless" (w: ^Wave_Buffer) -> bool {
	for {
		s := get_state(w)
		if s == .Empty { return true }
		if s == .Dead { return false }
		jsync.wait_while(&w.state, u32(s))
	}
}
