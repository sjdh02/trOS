const index = @import("index.zig");
const errorTypes = index.errorTypes;

pub const Register = union(enum) {
    ReadOnly: u32,
    WriteOnly: u32,
    ReadWrite: u32,
};

fn write(reg: Register) errorTypes.RegisterError!void {
    switch (reg) {
        Register.ReadOnly => {
            return errorTypes.RegisterError.BadType;
        },
        else => {
            return;
        }
    }
}

test "Register Union" {
    const std = @import("std");
    const x = Register{ .ReadOnly = 1234 };
    const y = Register{ .WriteOnly = 1234 };
    const z = Register{ .ReadWrite = 1234 };
    std.debug.assert(@typeOf(x) == Register);
    std.debug.assert(@typeOf(y) == Register);
    std.debug.assert(@typeOf(z) == Register);

    std.testing.expectError(errorTypes.RegisterError.BadType, (write(x)));

    try write(y);
    try write(z);
}
