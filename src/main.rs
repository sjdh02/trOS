#![no_std]
#![no_main]
#![feature(global_asm)]
#![feature(asm)]
#![allow(dead_code)]
#![allow(non_snake_case)] // Silence rust complaining about tOS vs t_os


mod gpio;
mod mmio;
mod mbox;
#[macro_use]
mod uart;
mod framebuffer;

use uart::UART0;

#[panic_handler]
fn panic(info: &core::panic::PanicInfo) -> ! {
    serial_put!("{}", info);
    loop {}
}

// Boot assembly
global_asm!(include_str!("boot.S"));

// @TODO: Implement markers for whether an addres is RW, WO, or RO to prevent
// erroneous reads or writes. This should probably be done with traits.

#[no_mangle]
extern "C" fn kmain() -> ! {
    let mut postman = mbox::MailBox::new();
    UART0.lock().init(&mut postman);
    serial_put!("tOS V0.1\n");
    serial_put!("READY:> ");

    let mut lfb = framebuffer::FrameBufferStream::new(1920, 1080);
    lfb.init(&mut postman);
    lfb.clear((Some(255), Some(255), Some(255)));
    loop {
        let x = UART0.lock().get();
        serial_put!("{}", x);
    }
}
