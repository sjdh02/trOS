# trOS
trOS is a small, rust and assembly, aarch64 rpi3 bare metal OS thingy.

Here is some stuff that works:
* mailbox calls
* uart0
* framebuffer (initializing/clearing)
* gpio
* mmio

Here is some stuff that doesn't quite work:
* drawing characters to the framebuffer (working on this)
* reading from the sd card
* anything not mentioned in the "stuff that works" section

# Building
You'll need `cargo` and `cargo-xbuild` for the build. once you have those,
run:
```
sh build
# or
./build
```
the binary will be in `trOS_core/target/aarch64-unknown-none/debug/`.

# Running
You can run this with qemu or use objcopy to throw it in an img file for booting
on real hardware. Note that it hasn't been tested on real hardware, but should work
fine. Running with qemu is easy:
```
qemu-system-aarch64 -kernel trOS_core/target/aarch64-unknown-none/debug/trOS -m 256 -M raspi3 -serial stdio
```
You can redirect `-serial` wherever you prefer. 

Alternatively, to both build and run with qemu, make the `run` file executable and run it.
It invokes the `xbuild` command and then fires up qemu.

# Disclaimer
A lot of this code is far from safe and likely not too idiomatic. Don't expect anything amazing here,
at least not for know. Just know that I do intend to improve it over time.
