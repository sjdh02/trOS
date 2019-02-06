use crate::mmio::*;


pub static VCORE_MBOX: u32 = MMIO_BASE + 0x0000B880;
pub static MBOX_READ: u32 = VCORE_MBOX + 0x0;
pub static MBOX_POLL: u32 = VCORE_MBOX + 0x10;
pub static MBOX_SENDER: u32 = VCORE_MBOX + 0x14;
pub static MBOX_STATUS: u32 = VCORE_MBOX + 0x18;
pub static MBOX_CONFIG: u32 = VCORE_MBOX + 0x1C;
pub static MBOX_WRITE: u32 = VCORE_MBOX + 0x20;
pub static MBOX_RESPONSE: u32 = 0x80000000;
pub static MBOX_FULL: u32 = 0x80000000;
pub static MBOX_EMPTY: u32 = 0x40000000;
pub static MBOX_REQUEST: u32 = 0;
// Channels
pub static MBOX_CH_POWER: u32 = 0;
pub static MBOX_CH_FB: u32 = 1;
pub static MBOX_CH_VUART: u32 = 2;
pub static MBOX_CH_VCHIQ: u32 = 3;
pub static MBOX_CH_LEDS: u32 = 4;
pub static MBOX_CH_BTNS: u32 = 5;
pub static MBOX_CH_TOUCH: u32 = 6;
pub static MBOX_CH_COUNT: u32 = 7;
pub static MBOX_CH_PROP: u32 = 8;
// Tags
pub static MBOX_TAG_GETSERIAL: u32 = 0x10004;
pub static MBOX_TAG_SETPOWER: u32 = 0x28001;
pub static MBOX_TAG_SETCLKRATE: u32 = 0x38002;
pub static MBOX_TAG_LAST: u32 = 0;

// The only way to align the array properly is by putting it in a struct
// that is 16 byte aligned. This may not be the worst thing, however, as
// it allows grouping of functions related to the mailbox interface under
// a single struct.

#[repr(align(16))] // 16 byte align
pub struct MailBox {
    pub mbox: [u32; 36],
}

impl MailBox {
    /// Initialize a new `MailBox` struct with a zeroed-out `mbox` array.
    pub fn new() -> MailBox {
        MailBox{
            // Zero initialize
            mbox: [0; 36]
        }
    }

    /// Clear the `mbox` array.
    pub fn clear(&mut self) {
        self.mbox = [0; 36];
    }

    /// Perform a mailbox call.
    pub fn call(&self, d: u32) -> bool {
        let ptr = self.mbox.as_ptr();
        let r = (ptr as u32) & (!0xF) | d & 0xF;

        unsafe {
            while (read(MBOX_STATUS) & MBOX_FULL) != 0 {
                wait(1);
            }
            write(MBOX_WRITE, r);
            loop {
                while (read(MBOX_STATUS) & MBOX_EMPTY) != 0 {
                    wait(1);
                }
                if read(MBOX_READ) == r { return self.mbox[1] == MBOX_RESPONSE}
            }
        }
    }
}
