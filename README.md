# trOS
trOS is a small, [zig](https://ziglang.org) and assembly, aarch64 RPI3 bare metal OS thingy.

some stuff that works:
* mailbox calls
* uart0
* framebuffer (initializing/clearing/printing characters and strings)
* gpio
* mmio

stuff that is being worked on:
* USB
* networking
* SD card support (priority!)
* anything else not mentioned above

# building
all you need to build is [zig](https://ziglang.org) itself. grab it and run:

```
zig build
```

the output file will be in `zig-cache`. alternatively, you can run the following to
launch qemu (will auto-detect windows or unix):

```
zig build qemu
```

you can have qemu redirect to a pty as well:

```
zig build qemu -Dpty
```

you can start a gdb remote server:

```
zig build qemu -Dgdb
```

you can combine the last two:

```
zig build qemu -Dpty -Dgdb
```

if you want a very small binary:

```
zig build -Drelease-fast
# or
zig build -Drelease-small
```

both of these produce a binary that is about ~5kb.

if you want release optimizations while still having safety checks:

```
zig build -Drelease-safe
```

and thats about all the build options. note that you can combine all `-D` options
with the `qemu` directive, e.g.:

```
zig build qemu -Drelease-small
```

will build a `release-small` binary and then run it with qemu.

# credit

thanks to [andrew kelly](https://github.com/andrewrk/clashos/) for the build file.
