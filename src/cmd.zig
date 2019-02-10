const std = @import("std");
const builtin = @import("builtin");
const index = @import("index.zig");

const errorTypes = index.errorTypes;
const uart = index.uart;

const NoError = error{};

pub const CommandParser = struct {
    var buffer: [4096]u8 = []u8{0} ** 4096;
    var idx: usize = 0;

    pub fn pushChar(self: *CommandParser, c: u8) void {
        if (idx == 4095) {
            idx = 0;
        }
        buffer[idx] = c;
        idx += 1;
    }

    pub fn parseCommand(self: *CommandParser) !void {
        // @TODO: Run through the buffer (up until idx) looking for a space
        // character. Once the index of a space character is found, slice
        // the buffer up to it to form the command.
        // @TODO: Support arguments for commands, maybe with the following
        // syntax: command{args, args1}.
        for (buffer[0..idx]) |data, fIdx| {
            switch(data) {
                '{' => {
                    const cmd = buffer[0..fIdx];
                    uart.write("{}\n", cmd);
                },
                else => {
                    uart.write("{}\n", data);
                    return;
                }
            }
        }
        if (buffer[4095] == '!') {
            return errorTypes.CommandError.ParseError;
        }
        idx = 0;
        return;
    }
};
