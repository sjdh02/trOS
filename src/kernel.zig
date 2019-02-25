const builtin = @import("builtin");
const uart = @import("index.zig").uart;
const util = @import("index.zig").util;
const framebuffer = @import("index.zig").framebuffer;

// TODO(sam): Take in new boot images from the serial port for easier real hardware testing.

// TODO(sam): Parse input from UART0 and handle commands. Should just be able to
// read into a buffer, track the index, slice up to it (buffer[0..idx]) and
// take that as a []const u8 for matching as a command. We may need to implement
// a string.contains function of some kind since there will be arguments present
// as well.

// TODO(sam): Re-do docs.

pub fn panic(msg: []const u8, error_stack_trace: ?*builtin.StackTrace) noreturn {
    @setCold(true);
    uart.write("\nKERNEL PANIC: \n");
    uart.write("MESSAGE: {}", msg);
    uart.write("STACK TRACE:\n");
    util.hang();
}

export fn kmain() noreturn {
    uart.write("tOS v0.1\n");
    framebuffer.write("READY:> ");
    uart.write("READY:> ");
    while (true) {
        const x = uart.get();
        uart.put(x);
        framebuffer.put(x);
    }
    // enter low power state and hang if we get somehow get out of the while loop.
    util.powerOff();
    util.hang();
}
