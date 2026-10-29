package jsync

foreign import System "system:System.framework"

@(default_calling_convention="c")
foreign System {
	__ulock_wait :: proc(operation: u32, addr: rawptr, value: u64, timeout_us: u32) -> i32 ---
	__ulock_wake :: proc(operation: u32, addr: rawptr, wake_value: u64) -> i32 ---
}

UL_COMPARE_AND_WAIT :: 0x00000001
ULF_WAKE_ALL        :: 0x00000100
ULF_NO_ERRNO        :: 0x01000000

_platform_wait :: proc "contextless" (a: ^u32, expected: u32) {
	__ulock_wait(UL_COMPARE_AND_WAIT | ULF_NO_ERRNO, a, u64(expected), 0)
}

_platform_wake :: proc "contextless" (a: ^u32, n: u32) {
	op: u32 = UL_COMPARE_AND_WAIT | ULF_NO_ERRNO
	if n > 1 {
		op |= ULF_WAKE_ALL
	}
	__ulock_wake(op, a, 0)
}
