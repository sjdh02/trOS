const std = @import("std");
const index = @import("index.zig");

const mmio = index.mmio;
const uart = index.uart;

const Register = index.regs.Register;

pub const VCORE_MBOX: u32 = mmio.MMIO_BASE + 0x0000B880;
pub const MBOX_READ: Register = Register { .ReadOnly = VCORE_MBOX + 0x0 };
pub const MBOX_POLL: u32 = VCORE_MBOX + 0x10;
pub const MBOX_SENDER: u32 = VCORE_MBOX + 0x14;
pub const MBOX_STATUS: Register = Register { .ReadOnly = VCORE_MBOX + 0x18 };
pub const MBOX_CONFIG: u32 = VCORE_MBOX + 0x1C;
pub const MBOX_WRITE: Register = Register { .WriteOnly = VCORE_MBOX + 0x20 };
pub const MBOX_RESPONSE: u32 = 0x80000000;
pub const MBOX_FULL: u32 = 0x80000000;
pub const MBOX_EMPTY: u32 = 0x40000000;
pub const MBOX_REQUEST: u32 = 0;
// Channels
pub const MBOX_CH_POWER: u32 = 0;
pub const MBOX_CH_FB: u32 = 1;
pub const MBOX_CH_VUART: u32 = 2;
pub const MBOX_CH_VCHIQ: u32 = 3;
pub const MBOX_CH_LEDS: u32 = 4;
pub const MBOX_CH_BTNS: u32 = 5;
pub const MBOX_CH_TOUCH: u32 = 6;
pub const MBOX_CH_COUNT: u32 = 7;
pub const MBOX_CH_PROP: u32 = 8;
// Tags
pub const MBOX_TAG_GETSERIAL: u32 = 0x10004;
pub const MBOX_TAG_SETPOWER: u32 = 0x28001;
pub const MBOX_TAG_SETCLKRATE: u32 = 0x38002;
pub const MBOX_TAG_LAST: u32 = 0;

// @NOTE: This has to be an array of u32!
/// 16-bit aligned `u32` array for the mailbox calls.
pub var mbox: [36]u32 align(16) = []u32{0}**36;

/// Make a call to the mailbox to query information. Note that when running on
/// emulated hardware this may have different results, e.g. a serial number
/// query will always return 0.
pub fn mboxCall(d: u8) bool {
    const r: u32 = @intCast(u32, (@ptrToInt(&mbox) & ~u32(0xF))) | @intCast(u32, (@intCast(u32, d) & 0xF));
    while(mmio.readSafe(MBOX_STATUS) & MBOX_FULL != 0) {
        mmio.wait(1);
    }
    mmio.writeSafe(MBOX_WRITE, r);
    while (true) {
        while (mmio.readSafe(MBOX_STATUS) & MBOX_EMPTY != 0) {
            mmio.wait(1);
        }
        if (mmio.readSafe(MBOX_READ) == r)
            return mbox[1] == MBOX_RESPONSE;
    }
}

pub fn mboxGetSerial() void {
    // Setup the query
    mbox[0] = 8*4;
    mbox[1] = MBOX_REQUEST;
    mbox[2] = MBOX_TAG_GETSERIAL;
    mbox[3] = 8;
    mbox[4] = 8;
    mbox[5] = 0;
    mbox[6] = 0;
    mbox[7] = MBOX_TAG_LAST;
    // Make the call
    if (mboxCall(MBOX_CH_PROP)) {
        if (!uart.initState)
            uart.init();
        uart.write("{}{}\n", mbox[6], mbox[5]);
    }
}
