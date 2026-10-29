package file_thread

import "core:fmt"
import "core:os"
import "core:time"
import "../hooks"
import "../slot"
import jsync "../sync"

BYTES_PER_MS :: 100
CHUNK        :: 4096

Config :: struct {
	data_dir: string,
	slot:     ^slot.File_Slot,
	hooks:    ^hooks.Hooks,
	kill:     ^jsync.Kill_Signal,
}

Stats :: struct {
	files: int,
	bytes: int,
	error: bool,
}

run :: proc(cfg: ^Config) -> Stats {
	stats: Stats
	hooks.file_buffer_info(cfg.hooks, &cfg.slot.data)
	for i in 0..<slot.NUM_FILES {
		if !slot.acquire_for_file(cfg.slot) { return stats }
		if cfg.kill != nil && jsync.kill_requested(cfg.kill) { return stats }

		n, ok := throttled_read(cfg.data_dir, i, cfg.slot.data[:])
		if !ok {
			stats.error = true
			slot.kill(cfg.slot)
			return stats
		}
		stats.files += 1
		stats.bytes += n
		slot.publish_to_coord(cfg.slot, n, i)
	}
	return stats
}

throttled_read :: proc(data_dir: string, index: int, dst: []u8) -> (total: int, ok: bool) {
	path := fmt.tprintf("%s/wave_%d.wav", data_dir, index)
	fd, err := os.open(path)
	if err != nil {
		fmt.eprintfln("file_thread: cannot open %s", path)
		return 0, false
	}
	defer os.close(fd)

	start := time.tick_now()
	for total < len(dst) {
		want := min(CHUNK, len(dst) - total)
		n, rerr := os.read(fd, dst[total:total + want])
		if rerr != nil {
			fmt.eprintfln("file_thread: read error on %s", path)
			return total, false
		}
		if n == 0 { break }
		total += n

		deadline := time.Duration(total) * time.Millisecond / BYTES_PER_MS
		remaining := deadline - time.tick_since(start)
		if remaining > 0 {
			time.sleep(remaining)
		}
	}
	return total, true
}
