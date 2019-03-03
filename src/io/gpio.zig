const io = @import("../io.zig");
const types = @import("../types.zig");

const mmio = io.mmio;

const Register = types.regs.Register;

pub const GPFSEL0 = u32(mmio.MMIO_BASE + 0x00200000);
pub const GPFSEL1 = Register { .ReadWrite = mmio.MMIO_BASE + 0x00200004 };
pub const GPFSEL2 = u32(mmio.MMIO_BASE + 0x00200008);
pub const GPFSEL3 = u32(mmio.MMIO_BASE + 0x0020000C);
pub const GPFSEL4 = u32(mmio.MMIO_BASE + 0x00200010);
pub const GPFSEL5 = u32(mmio.MMIO_BASE + 0x00200014);
pub const GPSET0 = u32(mmio.MMIO_BASE + 0x0020001C);
pub const GPSET1 = u32(mmio.MMIO_BASE + 0x00200020);
pub const GPCLR0 = u32(mmio.MMIO_BASE + 0x00200028);
pub const GPLEV0 = u32(mmio.MMIO_BASE + 0x00200034);
pub const GPLEV1 = u32(mmio.MMIO_BASE + 0x00200038);
pub const GPEDS0 = u32(mmio.MMIO_BASE + 0x00200040);
pub const GPEDS1 = u32(mmio.MMIO_BASE + 0x00200044);
pub const GPHEN0 = u32(mmio.MMIO_BASE + 0x00200064);
pub const GPHEN1 = u32(mmio.MMIO_BASE + 0x00200068);
pub const GPPUD = Register { .WriteOnly = mmio.MMIO_BASE + 0x00200094 };
pub const GPPUDCLK0 = Register { .WriteOnly = mmio.MMIO_BASE + 0x00200098 };
pub const GPPUDCLK1 = u32(mmio.MMIO_BASE + 0x0020009C);
