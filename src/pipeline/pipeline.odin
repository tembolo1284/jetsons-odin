package pipeline

import "core:fmt"
import "core:thread"
import "../audio"
import "../coordinator"
import "../file_thread"
import "../hooks"
import "../messages"
import "../playback"
import "../slot"
import "../spsc"
import jsync "../sync"
import "../wave"

Sink_Kind :: enum {
	Device,
	Null,
}

Options :: struct {
	data_dir:   string,
	hooks:      ^hooks.Hooks,
	sink:       Sink_Kind,
	null_speed: f64,
}

Stats :: struct {
	pulls:           int,
	chunks:          int,
	bytes:           int,
	underrun_frames: u64,
	frames_rendered: u64,
	wave_cycles:     [wave.NUM_BUFFERS]int,
	sink_used:       Sink_Kind,
}

File_Run :: struct {
	cfg:   file_thread.Config,
	stats: file_thread.Stats,
}
Coord_Run :: struct {
	cfg:   coordinator.Config,
	stats: coordinator.Stats,
}
Play_Run :: struct {
	cfg:   playback.Config,
	stats: playback.Stats,
}

file_entry  :: proc(r: ^File_Run)  { r.stats = file_thread.run(&r.cfg) }
coord_entry :: proc(r: ^Coord_Run) { r.stats = coordinator.run(&r.cfg) }
play_entry  :: proc(r: ^Play_Run)  { r.stats = playback.run(&r.cfg) }

run :: proc(opts: Options) -> (stats: Stats, ok: bool) {
	s := new(slot.File_Slot)
	defer free(s)
	a := new(coordinator.Buffer)
	defer free(a)
	b := new(coordinator.Buffer)
	defer free(b)
	bufs := new([wave.NUM_BUFFERS]wave.Wave_Buffer)
	defer free(bufs)
	chan := new(messages.Channel)
	defer free(chan)
	engine := new(audio.Engine)
	defer free(engine)
	dev := new(audio.Device_Sink)
	defer free(dev)
	null := new(audio.Null_Sink)
	defer free(null)

	wave.init_all(bufs)
	audio.init(engine, bufs)
	kill: jsync.Kill_Signal
	prod, cons := spsc.split(&chan.ring)

	fr := File_Run{cfg = {data_dir = opts.data_dir, slot = s, hooks = opts.hooks, kill = &kill}}
	cr := Coord_Run{cfg = {slot = s, hooks = opts.hooks, kill = &kill, a = a, b = b, chan = chan, prod = prod}}
	pr := Play_Run{cfg = {chan = chan, cons = cons, bufs = bufs, engine = engine, kill = &kill}}

	sink := opts.sink
	if sink == .Device && !audio.device_start(dev, engine) {
		fmt.eprintln("audio: falling back to null sink")
		sink = .Null
	}
	stats.sink_used = sink

	null_th: ^thread.Thread
	if sink == .Null {
		audio.null_init(null, engine, opts.null_speed)
		null_th = thread.create_and_start_with_poly_data(null, audio.null_run)
	}

	wave_ths: [wave.NUM_BUFFERS]^thread.Thread
	for &t, i in wave_ths {
		t = thread.create_and_start_with_poly_data(&bufs[i], wave.run)
	}
	pt := thread.create_and_start_with_poly_data(&pr, play_entry)
	ct := thread.create_and_start_with_poly_data(&cr, coord_entry)
	ft := thread.create_and_start_with_poly_data(&fr, file_entry)

	thread.join(ft)
	thread.join(ct)
	thread.join(pt)
	if fr.stats.error {
		audio.force_drained(engine)
	} else {
		audio.wait_drained(engine)
	}

	if sink == .Device {
		audio.device_stop(dev)
	} else {
		audio.null_stop(null)
		thread.join(null_th)
		thread.destroy(null_th)
	}

	wave.kill_all(bufs)
	for t in wave_ths {
		thread.join(t)
		thread.destroy(t)
	}
	thread.destroy(ft)
	thread.destroy(ct)
	thread.destroy(pt)

	stats.pulls = cr.stats.pulls
	stats.chunks = cr.stats.chunks
	stats.bytes = cr.stats.bytes
	stats.underrun_frames = engine.underrun_frames
	stats.frames_rendered = engine.frames_rendered
	for &c, i in stats.wave_cycles {
		c = bufs[i].cycles
	}
	return stats, !fr.stats.error && cr.stats.pulls == slot.NUM_FILES
}
