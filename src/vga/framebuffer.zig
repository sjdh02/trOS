const builtin = @import("builtin");
const std = @import("std");
const index = @import("../index.zig");

const gpio = index.gpio;
const mmio = index.mmio;
const mbox = index.mbox;
const uart = index.uart;
const errorTypes = index.errorTypes;

/// Embedded PSF font file
const fontEmbed = @embedFile("font.psf");

const NoError = error{};

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
const FrameBufferStream = struct {
    width: u32,
    height: u32,
    pitch: u32,
    x: u32,
    y: u32,
    font: *const PSFFont,
    ptr: [*]volatile u8,

    // Simple alias for FrameBufferStream
    const Self = @This();

    pub fn init(width: u32, height: u32, pitch: u32,
    ptr: [*]volatile u8, font: *const PSFFont) Self {
        return Self{
            .width = width,
            .height = height,
            .pitch = pitch,
            .x = 0,
            .y = 0,
            .font = font,
            .ptr = ptr,
        };
    }

    pub fn put(self: *Self, c: u8) void {
        const bytesPerLine = (self.font.width + 7) / 8;
        var offset = (self.y * self.font.height * self.pitch) + (self.x * (self.font.width + 1) * 4);
        var glyph = @ptrToInt(&fontEmbed);
        switch(c) {
            '\r' => {
                self.writeBytes("\n");
                self.writeBytes("READY:> ");
            },
            '\n' => {
                self.x = 0;
                self.y += 1;
            },
            else => {
                if (c < self.font.numglyph) {
                    glyph += (self.font.headersize + (c * self.font.bytesPerGlyph));
                } else {
                    glyph += (self.font.headersize + (0 * self.font.bytesPerGlyph));
                }
                var y: usize = 0;
                while (y < self.font.height) : (y += 1) {
                    var line = offset;
                    var mask = u32(1) << @truncate(u5, (self.font.width - 1));
                    var x: usize = 0;
                    while (x < self.font.width) : (x += 1) {
                        var color: u8 = undefined;
                        if ((@intToPtr(*const u8, glyph).* & mask) == 0) {
                            color = 0;
                        } else {
                            color = 255;
                        }
                        self.ptr[line] = color;
                        self.ptr[line + 1] = color;
                        self.ptr[line + 2] = color;
                        mask >>= 1;
                        line += 4;
                    }
                    glyph += bytesPerLine;
                    offset += self.pitch;
                }
            },
        }
        self.x += 1;
    }

    pub fn writeBytes(self: *Self, data: []const u8) void {
        for (data) |c| {
            self.put(c);
        }
    }
};

/// `Stream` is a `FrameBufferStream` that conatins the width, height,
/// pitch, x/y pos, font, and pointer for the framebuffer. It handles
/// all operations on the framebuffer via its methods.
var Stream: FrameBufferStream = undefined;

/// Initialize both the physical and virtual framebuffer with a resolution of
/// 1024x768.
pub fn init() !void {
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

    if (mbox.mboxCall(mbox.MBOX_CH_PROP) and mbox.mbox[20] == 32 and mbox.mbox[28] != 0) {
        mbox.mbox[28] &= 0x3FFFFFFF;
        Stream = FrameBufferStream.init(mbox.mbox[5], mbox.mbox[6], mbox.mbox[33],
                                        @intToPtr([*]volatile u8, mbox.mbox[28]),
                                        @ptrCast(*const PSFFont, &fontEmbed));
    } else {
        return errorTypes.FrameBufferError.InitializationError;
    }
}

/// `put` is a public wrapper around the `put` function contained within
/// `FrameBufferStream`.
pub fn put(c: u8) void {
    Stream.put(c);
}

/// `writeHandler` handles write requests for the framebuffer from `write`.
fn writeHandler(context: void, data: []const u8) NoError!void {
    Stream.writeBytes(data);
}

/// `write` manages all writes for the framebuffer. It takes formatted arguments, in the
/// same manner that `std.debug.warn()` does. It then passes them to `writeHandler`
/// for writing out.
pub fn write(comptime data: []const u8, args: ...) void {
    std.fmt.format({}, NoError, writeHandler, data, args) catch |e| switch (e) {};
}

