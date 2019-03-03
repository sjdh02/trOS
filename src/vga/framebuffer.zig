const std = @import("std");
const io = @import("../io.zig");
const types = @import("../types.zig");

const gpio = io.gpio;
const mmio = io.mmio;
const mbox = io.mbox;
const uart = io.uart;

const Register = types.regs.Register;
const NoError = types.errorTypes.NoError;

const fontEmbed = @embedFile("font.psf");

/// Respresent a PSF font.
const PSFFont = packed struct {
    magic: u32,
    version: u32,
    headersize: u32,
    flags: u32,
    numglyph: u32,
    bytesPerGlyph: u32,
    height: u32,
    width: u32,
};

/// FrameBufferStream is a struct that handles framebuffer writes.
/// Note that it also handles parsing PSF fonts and doing glyph
/// lookups when performing a write.
pub const FrameBuffer = struct {
    const Self = @This();

    var width: u32 = undefined;
    var height: u32 = undefined;
    var pitch: u32 = undefined;
    // @NOTE: This should work well for on-the-fly font changes.
    // For example, we could start with a non-unicode font, then
    // swap to one if the need arises and continue printing seemlessly.
    var font: *const PSFFont = @ptrCast(*const PSFFont, &fontEmbed);
    var ptr: [*]volatile u8 = undefined;

    var column: u32 = 0;
    var row: u32 = 0;

    var initState = false;


    fn init() ?void {
        mbox.mbox[0] = 35*4;
        mbox.mbox[1] = mbox.MBOX_REQUEST;
        mbox.mbox[2] = 0x48003;  //set phy wh
        mbox.mbox[3] = 8;
        mbox.mbox[4] = 8;
        mbox.mbox[5] = 1920;
        mbox.mbox[6] = 1080;

        mbox.mbox[7] = 0x48004;  //set virt wh
        mbox.mbox[8] = 8;
        mbox.mbox[9] = 8;
        mbox.mbox[10] = 1920;
        mbox.mbox[11] = 1080;

        mbox.mbox[12] = 0x48009; //set virt offset
        mbox.mbox[13] = 8;
        mbox.mbox[14] = 8;
        mbox.mbox[15] = 0;
        mbox.mbox[16] = 0;

        mbox.mbox[17] = 0x48005; //set depth
        mbox.mbox[18] = 4;
        mbox.mbox[19] = 4;
        mbox.mbox[20] = 32;

        mbox.mbox[21] = 0x48006; //set pixel order
        mbox.mbox[22] = 4;
        mbox.mbox[23] = 4;
        mbox.mbox[24] = 1;

        mbox.mbox[25] = 0x40001; //get framebuffer, gets alignment on request
        mbox.mbox[26] = 8;
        mbox.mbox[27] = 8;
        mbox.mbox[28] = 4096;
        mbox.mbox[29] = 0;

        mbox.mbox[30] = 0x40008; //get pitch
        mbox.mbox[31] = 4;
        mbox.mbox[32] = 4;
        mbox.mbox[33] = 0;

        mbox.mbox[34] = mbox.MBOX_TAG_LAST;

        if ((mbox.mboxCall(mbox.MBOX_CH_PROP) != null) and mbox.mbox[20] == 32 and mbox.mbox[28] != 0) {
            mbox.mbox[28] &= 0x3FFFFFFF;
            width = mbox.mbox[5];
            height = mbox.mbox[6];
            pitch = mbox.mbox[33];
            ptr = @intToPtr([*]volatile u8, mbox.mbox[28]);
        } else {
            return null;
        }
    }

    fn put(c: u8) void {
        const bytesPerLine = (font.width + 7) / 8;
        var offset = (row * font.height * pitch) + (column * (font.width + 1) * 4);
        var idx = usize(0);
        switch(c) {
            '\r' => {
                writeBytes("\n");
                writeBytes("READY:> ");
            },
            '\n' => {
                column = 0;
                row += 1;
            },
            // Backspace
            8 => {
                if (column > 8)
                    column -= 1;
                offset = (row * font.height * pitch) + (column * (font.width + 1) * 4);
                var y: usize = 0;
                while (y < font.height) : (y += 1) {
                    var line = offset;
                    var x: usize = 0;
                    while (x < font.width) : (x += 1) {
                        ptr[line] = 0;
                        ptr[line + 1] = 0;
                        ptr[line + 2] = 0;
                        line += 4;
                    }
                    offset += pitch;
                }
            },
            else => {
                if (c < font.numglyph) {
                    idx += (font.headersize + (c * font.bytesPerGlyph));
                } else {
                    idx += (font.headersize + (0 * font.bytesPerGlyph));
                }
                var y: usize = 0;
                while (y < font.height) : (y += 1) {
                    var line = offset;
                    var mask = u32(1) << @truncate(u5, (font.width - 1));
                    var x: usize = 0;
                    while (x < font.width) : (x += 1) {
                        var color: u8 = undefined;
                        if ((fontEmbed[idx]) & mask == 0) {
                            color = 0;
                        } else {
                            color = 255;
                        }
                        ptr[line] = color;
                        ptr[line + 1] = color;
                        ptr[line + 2] = color;
                        mask >>= 1;
                        line += 4;
                    }
                    idx += bytesPerLine;
                    offset += pitch;
                }
                column += 1;
            },
        }
    }

    pub fn writeBytes(data: []const u8) void {
        if (!initState)
            init().?;
        for (data) |c| {
            put(c);
        }
    }
};


/// `put` is a public wrapper around the `put` function contained within
/// `FrameBufferStream`.
pub fn put(c: u8) void {
    FrameBuffer.put(c);
}

/// `writeHandler` handles write requests for the framebuffer from `write`.
fn writeHandler(context: void, data: []const u8) NoError!void {
    FrameBuffer.writeBytes(data);
}

/// `write` manages all writes for the framebuffer. It takes formatted arguments, in the
/// same manner that `std.debug.warn()` does. It then passes them to `writeHandler`
/// for writing out.
pub fn write(comptime data: []const u8, args: ...) void {
    std.fmt.format({}, NoError, writeHandler, data, args) catch |e| switch (e) {};
}

// @PENDING-FIX: Test fails with: "TODO buf_read_value_bytes packed struct"
//test "PSFFont read test" {
//    const font = @ptrCast(*const PSFFont, &fontEmbed);
//    uart.write("{}", font);
//    std.debug.assert(font.magic == 2253043058);
//    std.debug.assert(font.version == 0);
//    std.debug.assert(font.headersize == 32);
//    std.debug.assert(font.flags == 786432);
//    std.debug.assert(font.numglyph == 128);
//    std.debug.assert(font.bytesPerGlyph == 16);
//    std.debug.assert(font.height == 16);
//    std.debug.assert(font.width == 8);
//}
