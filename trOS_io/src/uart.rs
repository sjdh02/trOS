use core::fmt;

use trOS_phys::mmio::*;
use trOS_phys::gpio::{GPFSEL1, GPPUD, GPPUDCLK0};
use trOS_mbox::mbox::*;
use spin::Mutex;
use lazy_static::lazy_static;

// @TODO: Implement formatter for this if possible, or do some macro magic.

static UART_DR: u32 = MMIO_BASE + 0x0020_1000;
static UART_FR: u32 = MMIO_BASE + 0x0020_1018;
static UART_IBRD: u32 = MMIO_BASE + 0x0020_1024;
static UART_FBRD: u32 = MMIO_BASE + 0x0020_1028;
static UART_LCRH: u32 = MMIO_BASE + 0x0020_102C;
static UART_CR: u32 = MMIO_BASE + 0x0020_1030;
static UART_IMSC: u32 = MMIO_BASE + 0x0020_1038;
static UART_ICR: u32 = MMIO_BASE + 0x0020_1044;

pub struct UART {
    mu_io_addr: u32,
    mu_lsr_addr: u32,
}

impl Default for UART {
    fn default() -> Self {
        UART{
            mu_io_addr: UART_DR,
            mu_lsr_addr: UART_FR,
        }
    }
}

impl UART {
    pub fn new() -> Self {
        UART{
            mu_io_addr: UART_DR,
            mu_lsr_addr: UART_FR,
        }
    }

    pub fn init(&mut self, mbox: &mut MailBox) {
        unsafe { write(UART_CR as *mut u32, 0); }
        // Setup mailbox call
        mbox.mbox[0] = 9*4;
        mbox.mbox[1] = MBOX_REQUEST;
        mbox.mbox[2] = MBOX_TAG_SETCLKRATE;
        mbox.mbox[3] = 12;
        mbox.mbox[4] = 8;
        mbox.mbox[5] = 2;
        mbox.mbox[6] = 4_000_000;
        mbox.mbox[7] = 0;
        mbox.mbox[8] = MBOX_TAG_LAST;
        mbox.call(MBOX_CH_PROP);

        let mut r: u32 = unsafe { read(GPFSEL1 as *const u32) };
        // Clean GPIO pins 14 & 15
        r &= (7 << 12) | (7 << 15);
        // Set alt0 for pins 14 and 15. alt0 functionality on these pins is Tx/Rx
        // respectively for UART0. Note that alt5 on these pins is Tx/Rx for UART1.
        r |= (4 << 12) | (4 << 15);
        unsafe {
            write(GPFSEL1 as *mut u32, r);
            // Write zero to GPPUD to set the pull up/down state to 'neither'
            write(GPPUD as *mut u32, 0);
            // Wait 150 cycles for GPPUD changes
            wait(150);
            // Mark the pins that are going to be modified by writing them into GPPUDCLK0
            // This makes sure that only pins 14 and 15 are set to the 'neither' state.
            write(GPPUDCLK0 as *mut u32, (1 << 14) | (1 << 15));
            wait(150);
            // Remove above clock for any future GPPUDCLK0 operations so they don't get
            // the wrong pins to modify
            write(GPPUDCLK0 as *mut u32, 0);
            // Clear interrupts
            write(UART_ICR as *mut u32, 0x7FF);
            // 115200 baud
            write(UART_IBRD as *mut u32, 2);
            write(UART_FBRD as *mut u32, 0xB);
            write(UART_LCRH as *mut u32, 0b11 << 15);
            write(UART_CR as *mut u32, 0x301);
        }
    }

    pub fn put(&mut self, c: char) {
        unsafe {
            while read(self.mu_lsr_addr as *const u32) & 0x20 != 0 {}
            match c {
                '\n' => {
                    write(self.mu_io_addr as *mut u32, '\n'.into());
                    write(self.mu_io_addr as *mut u32, '\r'.into());
                },
                '\r' => {
                    self.put('\n');
                    self.write("READY:> ");
                },
                _ => {
                    write(self.mu_io_addr as *mut u32, c.into());
                }
            }
        }
    }

    pub fn get(&self) -> char {
        unsafe {
            while (read(self.mu_lsr_addr as *const u32) & 0x10) != 0 {}
            (read(self.mu_io_addr as *const u32) as u8) as char
        }
    }

    pub fn write(&mut self, data: &str) {
        for c in data.as_bytes() {
            self.put(*c as char);
        }
    }
}

impl fmt::Write for UART {
    fn write_str(&mut self, s: &str) -> fmt::Result {
        self.write(s);
        Ok(())
    }
}

// Adapted from phil-op's kernel series

lazy_static! {
    pub static ref UART0: Mutex<UART> = Mutex::new(UART::new());
}

#[doc(hidden)]
pub fn _print(args: core::fmt::Arguments) {
    use core::fmt::Write;
    UART0.lock().write_fmt(args).unwrap();
}

#[macro_export]
macro_rules! serial_put {
    ($($arg:tt)*) => ($crate::uart::_print(format_args!($($arg)*)));
}
