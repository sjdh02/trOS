const AtomicOrder = @import("builtin").AtomicOrder;
const types = @import("../types.zig");
const regs = types.regs;

const Register = regs.Register;

/// Base address for the MMIO operations.
pub const MMIO_BASE = u32(0x3F000000);

// @TODO @PENDING-FIX: We should mark the register arguments below as compile time
// and then use @compileError in the bad bracnhes to catch bad register types at
// compile time. Currently, marking them as comptime causes the compiler to emit
// the following error: "TODO const expr analyze union field value for equality".
// It would allow us to elimiate the ?void return type as well, since the only
// error would be caught at compile time.

/// Write data to a given MMIO register, returning null
/// if the register had an incorrect type.
pub fn write(reg: Register, data: u32) ?void {
    @fence(AtomicOrder.SeqCst);
    switch (reg) {
        Register.ReadOnly => return null,
        Register.WriteOnly => {
            @intToPtr(*volatile u32, reg.WriteOnly).* = data;
        },
        Register.ReadWrite => {
            @intToPtr(*volatile u32, reg.ReadWrite).* = data;
        }
    }
}

/// Read data to a given MMIO register, returning null.
/// if the register had an incorrect type.
pub fn read(reg: Register) ?u32 {
    @fence(AtomicOrder.SeqCst);
    switch (reg) {
        Register.WriteOnly => return null,
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
