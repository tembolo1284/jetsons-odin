package slot

import "base:intrinsics"
import jsync "../sync"

SLOT_SIZE :: 512 * 1024
NUM_FILES :: 23

Owner :: enum u32 {
	File  = 0,
	Coord = 1,
	Dead  = 2,
}

File_Slot :: struct {
	owner: u32,
	size:  int,
	index: int,
	data:  [SLOT_SIZE]u8,
}

acquire_for_file :: proc "contextless" (s: ^File_Slot) -> bool {
	jsync.wait_while(&s.owner, u32(Owner.Coord))
	return intrinsics.atomic_load_explicit(&s.owner, .Acquire) == u32(Owner.File)
}

publish_to_coord :: proc "contextless" (s: ^File_Slot, size: int, index: int) {
	s.size = size
	s.index = index
	intrinsics.atomic_store_explicit(&s.owner, u32(Owner.Coord), .Release)
	jsync.wake_one(&s.owner)
}

acquire_for_coord :: proc "contextless" (s: ^File_Slot) -> bool {
	jsync.wait_while(&s.owner, u32(Owner.File))
	return intrinsics.atomic_load_explicit(&s.owner, .Acquire) == u32(Owner.Coord)
}

release_to_file :: proc "contextless" (s: ^File_Slot) {
	intrinsics.atomic_store_explicit(&s.owner, u32(Owner.File), .Release)
	jsync.wake_one(&s.owner)
}

kill :: proc "contextless" (s: ^File_Slot) {
	intrinsics.atomic_store_explicit(&s.owner, u32(Owner.Dead), .Release)
	jsync.wake_all(&s.owner)
}
