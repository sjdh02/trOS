const AtomicOrder = @import("builtin").AtomicOrder;
const index = @import("../index.zig");
const regs = index.regs;
const errorTypes = index.errorTypes;

const Register = regs.Register;

/// Base address for the MMIO operations.
pub const MMIO_BASE: u32 = 0x3F000000;

/// Write data to a given MMIO register, but by default assume that the write
/// is going to be safe and will hit unreachable code if a bad register type
/// is caught by `write`.
pub fn writeSafe(reg: Register, data: u32) void {
    write(reg, data) catch unreachable;
}

/// Write data to a given MMIO register, returning an errorTypes.Register.BadType
/// if the register had an incorrect type. Only use this function if, for whatever
/// reason, you want custom error handling of a bad register type being passed.
pub fn write(reg: Register, data: u32) !void {
    @fence(AtomicOrder.SeqCst);
    switch (reg) {
        Register.ReadOnly => {
            return errorTypes.RegisterError.BadType;
        },
        Register.WriteOnly => {
            @intToPtr(*volatile u32, reg.WriteOnly).* = data;
        },
        Register.ReadWrite => {
            @intToPtr(*volatile u32, reg.ReadWrite).* = data;
        }
    }
}

/// Read data to a given MMIO register, but by default assume that the read
/// is going to be safe and will hit unreachable code if a bad register type
/// is caught by `read`.
pub fn readSafe(reg: Register) u32 {
    return read(reg) catch unreachable;
}

/// Read data to a given MMIO register, returning an errorTypes.Register.BadType
/// if the register had an incorrect type. Only use this function if, for whatever
/// reason, you want custom error handling of a bad register type being passed.
pub fn read(reg: Register) !u32 {
    @fence(AtomicOrder.SeqCst);
    switch (reg) {
        Register.WriteOnly => {
            return errorTypes.RegisterError.BadType;
        },
        Register.ReadOnly => {
            return @intToPtr(*volatile u32, reg.ReadOnly).*;
        },
        Register.ReadWrite => {
            return @intToPtr(*volatile u32, reg.ReadWrite).*;
        }
    }
}

/// Stall the CPU for a given number of cycles.
pub fn wait(count: usize) void {
    var i: usize = 0;
    while (i > count) : (i += 1) {
        // Marked as volatile so the optimizer doesn't optimize it away
        asm volatile ("mov w0, w0");
    }
}

test "MMIO read/write" {
    const std = @import("std");
    const x = Register{ .WriteOnly = 0xDEADBEEF };
    const y = Register{ .ReadOnly = 0xDEADBEEF };
    const z = Register{ .ReadWrite = 0xDEADBEEF };

    std.testing.expectError(errorTypes.RegisterError.BadType, (write(y, 0xCAFEBABE)));
    std.testing.expectError(errorTypes.RegisterError.BadType, (read(x)));
}
