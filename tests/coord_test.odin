package tests

import "core:fmt"
import "core:os"
import "core:testing"
import "../src/file_thread"
import "../src/hooks"
import "../src/pipeline"
import "../src/slot"

Expected :: struct {
	size: int,
	crc:  u32,
}

EXPECTED := [slot.NUM_FILES]Expected{
	{0x80000, 0x295EAAAE}, {0x78000, 0x8A23BDD4}, {0x60000, 0x0E77ACF7},
	{0x40000, 0x8DD21B19}, {0x7C000, 0xD01E0081}, {0x20000, 0xAEE37AA9},
	{0x60000, 0x7DF652C1}, {0x80000, 0xADEE6397}, {0x70000, 0x170654EF},
	{0x40000, 0xDF7665C0}, {0x48000, 0x300CD9A1}, {0x20000, 0x035CDE29},
	{0x60000, 0x3D8F1E9B}, {0x20000, 0x6E6611A1}, {0x70000, 0xAC50EE8E},
	{0x7C000, 0xD869806B}, {0x24000, 0x162BE099}, {0x60000, 0x405CB153},
	{0x78000, 0x10793056}, {0x70000, 0xA1FEC2DC}, {0x70000, 0xB0567482},
	{0x7C000, 0xC6B67441}, {0x48E00, 0xEA869D7E},
}

data_dir :: proc() -> string {
	d := os.get_env("JETSONS_DATA", context.temp_allocator)
	return d if len(d) > 0 else "data"
}

@(test)
coord_test_23_transfers :: proc(t: ^testing.T) {
	dir := data_dir()
	if !os.exists(fmt.tprintf("%s/wave_0.wav", dir)) {
		testing.fail_now(t, "wave files not found; set JETSONS_DATA or run from repo root")
	}

	h := new(hooks.Hooks)
	defer free(h)
	hooks.init(h)

	stats, ok := pipeline.run({data_dir = dir, hooks = h, sink = .Null, null_speed = 20})
	testing.expect(t, ok, "pipeline reported failure")
	testing.expect_value(t, stats.pulls, slot.NUM_FILES)
	testing.expect_value(t, h.count, slot.NUM_FILES)

	testing.expect(t, h.file_buff != nil && h.coord_a != nil && h.coord_b != nil)
	testing.expect(t, h.file_buff != h.coord_a)
	testing.expect(t, h.file_buff != h.coord_b)
	testing.expect(t, h.coord_a != h.coord_b)

	total := 0
	t_old: f64 = 0
	for i in 0..<slot.NUM_FILES {
		tr := h.transfers[i]
		want_buff := h.coord_a if i % 2 == 0 else h.coord_b
		testing.expectf(t, tr.buff == want_buff, "transfer %d: wrong A/B buffer", i)
		testing.expectf(t, tr.size == EXPECTED[i].size, "transfer %d: size %x want %x", i, tr.size, EXPECTED[i].size)
		testing.expectf(t, tr.crc == EXPECTED[i].crc, "transfer %d: crc %08x want %08x", i, tr.crc, EXPECTED[i].crc)
		total += tr.size

		t_now := hooks.elapsed_ms(h, i)
		t_min := t_old + f64(EXPECTED[i].size) / f64(file_thread.BYTES_PER_MS)
		t_max := t_min + 500
		testing.expectf(t, t_now >= t_min, "transfer %d: delivered at %.1f ms, before %.1f ms", i, t_now, t_min)
		testing.expectf(t, t_now <= t_max, "transfer %d: delivered at %.1f ms, after %.1f ms", i, t_now, t_max)
		t_old = t_now
	}
	testing.expect_value(t, stats.bytes, total)
	testing.expect_value(t, stats.chunks, (total + 2047) / 2048)
}
