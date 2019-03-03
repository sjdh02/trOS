const errors = @import("errors.zig");
const io = @import("../io.zig");
const errorTypes = errors.errorTypes;

pub const Register = union(enum) {
    ReadOnly: u32,
    WriteOnly: u32,
    ReadWrite: u32,
};

test "Register Union" {
    const std = @import("std");
    const write = io.mmio.write;
    const read = io.mmio.read;
    const x = Register{ .WriteOnly = 0xDEADBEEF };
    const y = Register{ .ReadOnly = 0xDEADBEEF };
    const z = Register{ .ReadWrite = 0xDEADBEEF };

    std.debug.assert(null == (write(y, 0xCAFEBABE)));
    std.debug.assert(null == (read(x)));
}
