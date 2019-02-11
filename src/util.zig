const mmio = @import("index.zig").mmio;
const mbox = @import("index.zig").mbox;
const gpio = @import("index.zig").gpio;
const uart = @import("index.zig").uart;

/// Hang the system with an infinite while loop.
pub fn hang() noreturn {
    while (true) {}
}

const PM_RSTC: u32 = mmio.MMIO_BASE + 0x0010001C;
const PM_RSTS: u32 = mmio.MMIO_BASE + 0x00100020;
const PM_WDOG: u32 = mmio.MMIO_BASE + 0x00100024;
const PM_WDOG_MAGIC: u32 = 0x5A000000;
const PM_RSTC_FULLRST: u32 = 0x00000020;

/// Power the SoC down into a very low power state.
pub fn powerOff() void {
    var r: u32 = 0;

    while (r < 16) : (r += 1) {
        // Setup a mailbox call to power off each device
        mbox.mbox[0] = 8*4;
        mbox.mbox[1] = mbox.MBOX_REQUEST;
        mbox.mbox[2] = mbox.MBOX_TAG_SETPOWER;
        mbox.mbox[3] = 8;
        mbox.mbox[4] = 8;
        mbox.mbox[5] = r;
        mbox.mbox[6] = 0;
        mbox.mbox[7] = mbox.MBOX_TAG_LAST;
        _ = mbox.mboxCall(mbox.MBOX_CH_PROP);
    }

    // Power off GPIO pins
    mmio.writeSafe(gpio.GPFSEL0, 0);
    mmio.writeSafe(gpio.GPFSEL1, 0);
    mmio.writeSafe(gpio.GPFSEL2, 0);
    mmio.writeSafe(gpio.GPFSEL3, 0);
    mmio.writeSafe(gpio.GPFSEL4, 0);
    mmio.writeSafe(gpio.GPFSEL5, 0);
    mmio.writeSafe(gpio.GPPUD, 0);
    mmio.wait(150);
    mmio.writeSafe(gpio.GPPUDCLK0, 0xFFFFFFFF);
    mmio.writeSafe(gpio.GPPUDCLK1, 0xFFFFFFFF);
    mmio.wait(150);
    mmio.writeSafe(gpio.GPPUDCLK0, 0);
    mmio.writeSafe(gpio.GPPUDCLK1, 0);

    // Power off SoC
    r = mmio.readSafe(PM_RSTS);
    r &= ~u32(0xfffffaaa);
    // Indicate halt
    r |= 0x555;
    mmio.writeSafe(PM_RSTS, PM_WDOG_MAGIC | r);
    mmio.writeSafe(PM_RSTS, PM_WDOG_MAGIC | 10);
    mmio.writeSafe(PM_RSTS, PM_WDOG_MAGIC | PM_RSTC_FULLRST);
}

/// Reset the SoC
pub fn reset() void {
    var r: u32 = 0;

    r = mmio.readSafe(PM_RSTS);
    r &= ~u32(0xfffffaaa);
    mmio.writeSafe(PM_RSTS, PM_WDOG_MAGIC | r);
    mmio.writeSafe(PM_RSTS, PM_WDOG_MAGIC | 10);
    mmio.writeSafe(PM_RSTS, PM_WDOG_MAGIC | PM_RSTC_FULLRST);
}

// Constants for random number generator
pub const RNG_CTRL: u32 = mmio.MMIO_BASE + 0x00104000;
pub const RNG_STATUS: u32 = mmio.MMIO_BASE + 0x00104004;
pub const RNG_DATA: u32 = mmio.MMIO_BASE + 0x00104008;
pub const RNG_INT_MASK: u32 = mmio.MMIO_BASE + 0x00104010;

/// Initialize the random number generator
/// #NOTE: Currently just assuming this works until I can test on real hardware.
pub fn randInit() void {
    mmio.writeSafe(RNG_STATUS, 0x40000);
    var r = mmio.readSafe(RNG_INT_MASK);
    r |= 1;
    mmio.writeSafe(RNG_INT_MASK, r);
    r = mmio.readSafe(RNG_CTRL);
    r |= 1;
    mmio.writeSafe(RNG_CTRL, r);
    while ((@intToPtr(*volatile u32, RNG_STATUS).* >> 24) != 0) {
        mmio.wait(1);
    }
}

/// Get a random number between min and max.
pub fn getRand(min: usize, max: usize) usize {
    if (min > max)
        return 0;
    return ((mmio.readSafe(RNG_DATA)) % (max-min)) + min;
}
