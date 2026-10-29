package audio

import "core:fmt"
import ma "vendor:miniaudio"

Device_Sink :: struct {
	device: ma.device,
	engine: ^Engine,
	active: bool,
}

@(private)
device_callback :: proc "c" (dev: ^ma.device, output, input: rawptr, frame_count: u32) {
	e := cast(^Engine)dev.pUserData
	render(e, (cast([^]u8)output)[:int(frame_count) * BYTES_PER_FRAME])
}

device_start :: proc(s: ^Device_Sink, e: ^Engine) -> bool {
	s.engine = e
	cfg := ma.device_config_init(.playback)
	cfg.playback.format   = .s16
	cfg.playback.channels = CHANNELS
	cfg.sampleRate        = SAMPLE_RATE
	cfg.dataCallback      = device_callback
	cfg.pUserData         = e

	if r := ma.device_init(nil, &cfg, &s.device); r != .SUCCESS {
		fmt.eprintfln("audio: device_init failed (%v)", r)
		return false
	}
	if r := ma.device_start(&s.device); r != .SUCCESS {
		fmt.eprintfln("audio: device_start failed (%v)", r)
		ma.device_uninit(&s.device)
		return false
	}
	s.active = true
	return true
}

device_stop :: proc(s: ^Device_Sink) {
	if !s.active { return }
	ma.device_stop(&s.device)
	ma.device_uninit(&s.device)
	s.active = false
}
