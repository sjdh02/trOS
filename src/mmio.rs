use core::ptr::{read_volatile, write_volatile};

pub static MMIO_BASE: u32 = 0x3F000000;

// Note regarding these functions being marked as unsafe:
// You cannot call these functions safely on their own,
// however when they've been wrapped in a safe abstraction
// in a, for example, UART struct, they can then be called
// from safe rust code because we know that the address
// will be valid. They should be unsafe for direct calling
// because the address code gives to the function may
// be incorrect.

/// Write a `u32` piece of data to a `u32` address.
pub unsafe fn write(reg: u32, data: u32) {
    write_volatile(reg as *mut u32, data);
}

/// Read a `u32` piece of data from a `u32` address.
pub unsafe fn read(reg: u32) -> u32 {
    read_volatile(reg as *mut u32)
}

/// Wait for a given number of cycles by using inline assembly that the
/// compiler won't optimize away.
pub unsafe fn wait(cycles: usize) {
    for _ in 0..cycles {
        asm!("mov w0, w0" ::: : "volatile");
    }
}

