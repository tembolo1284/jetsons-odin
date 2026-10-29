package messages

import "../spsc"

RING_DEPTH :: 32

Fill_Cmd :: struct {
	data: [^]u8,
	len:  int,
	seq:  u32,
	last: bool,
}

Channel :: struct {
	ring:     spsc.Ring(Fill_Cmd, RING_DEPTH),
	cmd_seq:  u32,
	consumed: u32,
}

Producer :: spsc.Producer(Fill_Cmd, RING_DEPTH)
Consumer :: spsc.Consumer(Fill_Cmd, RING_DEPTH)
