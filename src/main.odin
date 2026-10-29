package main

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:time"
import "pipeline"

main :: proc() {
	opts := pipeline.Options{data_dir = "data", sink = .Device, null_speed = 1}
	args := os.args[1:]
	for i := 0; i < len(args); i += 1 {
		switch args[i] {
		case "--null":
			opts.sink = .Null
		case "--speed":
			i += 1
			opts.null_speed = strconv.parse_f64(args[i]) or_else 1
		case "--data":
			i += 1
			opts.data_dir = args[i]
		case:
			fmt.eprintfln("usage: jetsons [--null] [--speed F] [--data DIR]")
			os.exit(2)
		}
	}

	start := time.tick_now()
	stats, ok := pipeline.run(opts)
	elapsed := time.duration_seconds(time.tick_since(start))

	fmt.printfln("sink:            %v", stats.sink_used)
	fmt.printfln("files pulled:    %d", stats.pulls)
	fmt.printfln("chunks:          %d", stats.chunks)
	fmt.printfln("bytes:           %d", stats.bytes)
	fmt.printfln("frames rendered: %d", stats.frames_rendered)
	fmt.printfln("underrun frames: %d", stats.underrun_frames)
	fmt.printfln("wave cycles:     %v", stats.wave_cycles)
	fmt.printfln("elapsed:         %.1f s", elapsed)
	if !ok {
		os.exit(1)
	}
}
