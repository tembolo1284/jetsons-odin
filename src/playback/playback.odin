package playback

import "base:intrinsics"
import "../audio"
import "../messages"
import "../spsc"
import jsync "../sync"
import "../wave"

Config :: struct {
	chan:   ^messages.Channel,
	cons:   messages.Consumer,
	bufs:   ^[wave.NUM_BUFFERS]wave.Wave_Buffer,
	engine: ^audio.Engine,
	kill:   ^jsync.Kill_Signal,
}

Stats :: struct {
	chunks: int,
	bytes:  int,
}

run :: proc(cfg: ^Config) -> Stats {
	stats: Stats
	next := 0
	for {
		seen := intrinsics.atomic_load_explicit(&cfg.chan.cmd_seq, .Acquire)
		cmd, ok := spsc.pop(&cfg.cons)
		if !ok {
			if cfg.kill != nil && jsync.kill_requested(cfg.kill) { return stats }
			jsync.wait_while(&cfg.chan.cmd_seq, seen)
			continue
		}

		wb := &cfg.bufs[next]
		if !wave.wait_until_empty(wb) { return stats }

		copy(wb.data[:cmd.len], cmd.data[:cmd.len])
		wb.len = cmd.len
		wb.seq = cmd.seq
		if cmd.last {
			audio.set_final_seq(cfg.engine, cmd.seq + 1)
		}
		jsync.bump(&cfg.chan.consumed)
		wave.set_state(wb, .Filled)

		next = (next + 1) % wave.NUM_BUFFERS
		stats.chunks += 1
		stats.bytes += cmd.len
		if cmd.last { return stats }
	}
}
