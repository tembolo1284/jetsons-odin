package jsync

import "base:intrinsics"

SYS_FUTEX :: 202 when ODIN_ARCH == .amd64 else 98

FUTEX_WAIT    :: 0
FUTEX_WAKE    :: 1
FUTEX_PRIVATE :: 128

_platform_wait :: proc "contextless" (a: ^u32, expected: u32) {
	intrinsics.syscall(SYS_FUTEX, uintptr(a), FUTEX_WAIT | FUTEX_PRIVATE, uintptr(expected), 0, 0, 0)
}

_platform_wake :: proc "contextless" (a: ^u32, n: u32) {
	intrinsics.syscall(SYS_FUTEX, uintptr(a), FUTEX_WAKE | FUTEX_PRIVATE, uintptr(n), 0, 0, 0)
}
