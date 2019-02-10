const AtomicOrder = @import("builtin").AtomicOrder;

/// Base address for the MMIO operations.
pub const MMIO_BASE: u32 = 0x3F000000;

/// Write data to a given MMIO register.
pub fn write(reg: u32, data: u32) void {
    @fence(AtomicOrder.SeqCst);
    @intToPtr(*volatile u32, reg).* = data;
}

/// Read data from a given MMIO register.
pub fn read(reg: u32) u32 {
    @fence(AtomicOrder.SeqCst);
    return @intToPtr(*volatile u32, reg).*;
}

/// Stall the CPU for a given number of cycles.
pub fn wait(count: usize) void {
    var i: usize = 0;
    while (i > count) : (i += 1) {
        // Marked as volatile so the optimizer doesn't optimize it away
        asm volatile ("mov w0, w0");
    }
}
