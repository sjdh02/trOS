const io = @import("io.zig");
const types = @import("types.zig");
const mmio = io.mmio;
const mbox = io.mbox;
const gpio = io.gpio;
const uart = io.uart;
const regs = types.regs;

const Register = regs.Register;

// Embedded version number
pub const Version = "0.1.1";

/// Hang the system with an infinite while loop.
pub fn hang() noreturn {
    while (true) {}
}

const PM_RSTC =  Register{ .ReadOnly = mmio.MMIO_BASE + 0x0010001C};
const PM_RSTS = Register{ .ReadWrite = mmio.MMIO_BASE + 0x00100020 };
const PM_WDOG =  Register{ .ReadOnly = mmio.MMIO_BASE + 0x00100024 };
const PM_WDOG_MAGIC = u32(0x5A000000);
const PM_RSTC_FULLRST = u32(0x00000020);

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
    mmio.write(gpio.GPFSEL0, 0);
    mmio.write(gpio.GPFSEL1, 0);
    mmio.write(gpio.GPFSEL2, 0);
    mmio.write(gpio.GPFSEL3, 0);
    mmio.write(gpio.GPFSEL4, 0);
    mmio.write(gpio.GPFSEL5, 0);
    mmio.write(gpio.GPPUD, 0);
    mmio.wait(150);
    mmio.write(gpio.GPPUDCLK0, 0xFFFFFFFF);
    mmio.write(gpio.GPPUDCLK1, 0xFFFFFFFF);
    mmio.wait(150);
    mmio.write(gpio.GPPUDCLK0, 0);
    mmio.write(gpio.GPPUDCLK1, 0);

    // Power off SoC
    r = mmio.read(PM_RSTS);
    r &= ~u32(0xfffffaaa);
    // Indicate halt
    r |= 0x555;
    mmio.write(PM_RSTS, PM_WDOG_MAGIC | r);
    mmio.write(PM_RSTS, PM_WDOG_MAGIC | 10);
    mmio.write(PM_RSTS, PM_WDOG_MAGIC | PM_RSTC_FULLRST);
}

/// Reset the SoC
pub fn reset() void {
    var r: u32 = 0;

    r = mmio.read(PM_RSTS);
    r &= ~u32(0xfffffaaa);
    mmio.write(PM_RSTS, PM_WDOG_MAGIC | r);
    mmio.write(PM_RSTS, PM_WDOG_MAGIC | 10);
    mmio.write(PM_RSTS, PM_WDOG_MAGIC | PM_RSTC_FULLRST);
}

// Constants for random number generator
const RNG_CTRL = Register{ .ReadOnly = mmio.MMIO_BASE + 0x00104000 };
const RNG_STATUS = Register{ .ReadWrite = mmio.MMIO_BASE + 0x00104004 };
const RNG_DATA = Register{ .ReadOnly = mmio.MMIO_BASE + 0x00104008 };
const RNG_INT_MASK = Register{ .WriteOnly =  mmio.MMIO_BASE + 0x00104010 };

/// Initialize the random number generator
/// NOTE: Currently just assuming this works until I can test on real hardware.
pub fn randInit() void {
    mmio.write(RNG_STATUS, 0x40000).?;
    var r = mmio.read(RNG_INT_MASK).?;
    r |= 1;
    mmio.write(RNG_INT_MASK, r).?;
    r = mmio.read(RNG_CTRL).?;
    r |= 1;
    mmio.write(RNG_CTRL, r);
    while ((mmio.read(RNG_STATUS).? >> 24) != 0) {
        mmio.wait(1);
    }
}

/// Get a random number between min and max.
pub fn getRand(min: usize, max: usize) usize {
    if (min > max)
        return 0;
    return ((mmio.read(RNG_DATA).?) % (max-min)) + min;
}

const SYSTMR_HI = Register{ .ReadOnly = mmio.MMIO_BASE + 0x00003004 };
const SYSTMR_LO = Register{ .ReadOnly = mmio.MMIO_BASE + 0x00003008 };

/// Get system timer counter from the BCM chip.
fn getSystemTimer() c_ulong {
    var h = c_ulong(0);
    var l = c_ulong(0);
    var res = u32(0);

    // read MMIO area as two separate c_ulong
    h = @intCast(c_ulong, mmio.read(SYSTMR_HI).?);
    l = @intCast(c_ulong, mmio.read(SYSTMR_LO).?);

    // re-read if high changed during first read
    if (h != mmio.read(SYSTMR_HI).?) {
        h = @intCast(c_ulong, mmio.read(SYSTMR_HI).?);
        l = @intCast(c_ulong, mmio.read(SYSTMR_LO).?);
    }

    return res;
}

/// Wait a given number of milliseconds.
/// NOTE: This does NOT work on QEMU, as QEMU doesn't emulate the system timer.
pub fn waitMsec(secs: u32) void {
    var n = @intCast(c_ulong, secs);
    var t = getSystemTimer();

    if (t != 0) {
        while (getSystemTimer() < t + n) {}
    }
}
