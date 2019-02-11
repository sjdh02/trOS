const AtomicOrder = @import("builtin").AtomicOrder;
const regs = @import("../index.zig").regs;

const Register = regs.Register;

/// Base address for the MMIO operations.
pub const MMIO_BASE: u32 = 0x3F000000;

/// Write data to a given MMIO register.
pub fn write(reg: Register, data: u32) void {
    @fence(AtomicOrder.SeqCst);
    switch (reg) {
        Register.ReadOnly => {
            @panic("Error (mmio.write): Bad register type: Register.ReadOnly");
        },
        Register.WriteOnly => {
            @intToPtr(*volatile u32, reg.WriteOnly).* = data;
        },
        Register.ReadWrite => {
            @intToPtr(*volatile u32, reg.ReadWrite).* = data;
        }
    }
}

/// Read data from a given MMIO register.
pub fn read(reg: Register) u32 {
    @fence(AtomicOrder.SeqCst);
    switch (reg) {
        Register.WriteOnly => {
            @panic("Error (mmio.read): Bad register type: Register.WriteOnly");
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
