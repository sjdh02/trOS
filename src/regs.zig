pub const Register = union(enum) {
    ReadOnly: u32,
    WriteOnly: u32,
    ReadWrite: u32,
};


// @TODO: Move this to test suite and make this return a custom test error so we can use
// std.testing.expectError.
fn write(reg: Register) void {
    switch (reg) {
        Register.ReadOnly => {
            @panic("Wrong register type!");
        },
        else => {
            return;
        }
    }
}

test "Register union" {
    const std = @import("std");
    const x = Register{ .ReadOnly = 1234 };
    const y = Register{ .WriteOnly = 1234 };
    const z = Register{ .ReadWrite = 1234 };
    std.debug.assert(@typeOf(x) == Register);
    std.debug.assert(@typeOf(y) == Register);
    std.debug.assert(@typeOf(z) == Register);

    write(y);
    write(z);
}
