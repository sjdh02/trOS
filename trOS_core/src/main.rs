#![no_std]
#![no_main]
#![feature(global_asm)]
#![allow(non_snake_case)]

#[macro_use]
extern crate trOS_io;

use trOS_io::uart::UART0;

use trOS_io::framebuffer::LFB;
use trOS_mbox::mbox;

#[panic_handler]
fn panic(info: &core::panic::PanicInfo) -> ! {
    serial_put!("{}", info);
    loop {}
}

// Boot assembly
global_asm!(include_str!("boot.S"));

// @TODO: Implement markers for whether an addres is RW, WO, or RO to prevent
// erroneous reads or writes. This should probably be done with traits.

// @TODO: Custom error types.

// @TODO: Buffer seral reads. E.G.:
// 1. Get input
// 2. Send input to buffer
// 3. Send input back to serial port to display
// 4. On enter key, parse buffer and execute command within.
// We'll need to track the index in a buffer to do this, but it should be easy
// enough to actually implement.

// @TODO: Spend some time refactoring to remove unsafe code.


#[no_mangle]
extern "C" fn kmain() -> ! {
    let mut postman = mbox::MailBox::new();
    UART0.lock().init(&mut postman);
    serial_put!("tOS V0.1\n");
    serial_put!("READY:> ");

    LFB.lock().init(&mut postman).unwrap();

    loop {
        let x = UART0.lock().get();
        serial_put!("{}", x);
        framebuffer_put!("{}", x);
    }
}
