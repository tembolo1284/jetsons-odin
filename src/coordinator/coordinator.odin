package coordinator

import "base:intrinsics"
import "../hooks"
import "../messages"
import "../slot"
import "../spsc"
import jsync "../sync"
import "../wave"

Buffer :: [slot.SLOT_SIZE]u8

Config :: struct {
	slot:  ^slot.File_Slot,
	hooks: ^hooks.Hooks,
	kill:  ^jsync.Kill_Signal,
	a:     ^Buffer,
	b:     ^Buffer,
	chan:  ^messages.Channel,
	prod:  messages.Producer,
}

Stats :: struct {
	pulls:  int,
	bytes:  int,
	chunks: int,
}

run :: proc(cfg: ^Config) -> Stats {
	stats: Stats
	hooks.coord_a_buffer_info(cfg.hooks, cfg.a)
	hooks.coord_b_buffer_info(cfg.hooks, cfg.b)

	last_seq: [2]u32
	seq: u32 = 0

	for i in 0..<slot.NUM_FILES {
		idx := i % 2
		dst := cfg.a if idx == 0 else cfg.b

		if last_seq[idx] != 0 {
			jsync.wait_until_at_least(&cfg.chan.consumed, last_seq[idx])
		}
		if !slot.acquire_for_coord(cfg.slot) { break }
		if cfg.kill != nil && jsync.kill_requested(cfg.kill) { break }

		n := cfg.slot.size
		copy(dst[:n], cfg.slot.data[:n])
		hooks.data_transfer(cfg.hooks, dst, n)
		slot.release_to_file(cfg.slot)
		stats.pulls += 1
		stats.bytes += n

		off := 0
		for off < n {
			clen := min(wave.BUFFER_BYTES, n - off)
			cmd := messages.Fill_Cmd{
				data = raw_data(dst[off:]),
				len  = clen,
				seq  = seq,
				last = i == slot.NUM_FILES - 1 && off + clen >= n,
			}
			for {
				c := intrinsics.atomic_load_explicit(&cfg.chan.consumed, .Acquire)
				if spsc.push(&cfg.prod, cmd) { break }
				if cfg.kill != nil && jsync.kill_requested(cfg.kill) { return stats }
				jsync.wait_while(&cfg.chan.consumed, c)
			}
			jsync.bump(&cfg.chan.cmd_seq)
			seq += 1
			off += clen
			stats.chunks += 1
		}
		last_seq[idx] = seq
	}

	jsync.wait_until_at_least(&cfg.chan.consumed, seq)
	return stats
}
