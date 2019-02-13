const index = @import("index.zig");
const errorTypes = index.errorTypes;

pub const Register = union(enum) {
    ReadOnly: u32,
    WriteOnly: u32,
    ReadWrite: u32,
};

test "Register Union" {
    const std = @import("std");
    const write = index.mmio.write;
    const read = index.mmio.read;
    const x = Register{ .WriteOnly = 0xDEADBEEF };
    const y = Register{ .ReadOnly = 0xDEADBEEF };
    const z = Register{ .ReadWrite = 0xDEADBEEF };

    std.debug.assert(null == (write(y, 0xCAFEBABE)));
    std.debug.assert(null == (read(x)));
}
