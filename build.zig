const builtin = @import("builtin");
const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) !void {
    const want_gdb = b.option(bool, "gdb", "Build for QEMU gdb server") orelse false;
    const want_pty = b.option(bool, "pty", "Create a separate serial port path") orelse false;

    const mode = b.standardReleaseOptions();
    const exe = b.addStaticExecutable("tOS", "src/kernel.zig");
    exe.addAssemblyFile("src/asm/boot.S");
    exe.addIncludeDir("src/vga");
    exe.setBuildMode(mode);

    exe.setLinkerScriptPath("./linker.ld");
    // Use eabihf for freestanding arm code with hardware float support
    exe.setTarget(builtin.Arch.aarch64v8, builtin.Os.freestanding, builtin.Environ.eabihf);

    const qemu = b.step("qemu", "run kernel in qemu");
    var qemu_args = std.ArrayList([]const u8).init(b.allocator);
    try qemu_args.appendSlice([][]const u8{
        if (builtin.os == builtin.Os.windows) "C:/Program Files/qemu/qemu-system-aarch64.exe" else "qemu-system-aarch64",
        "-kernel",
        exe.getOutputPath(),
        "-m",
        "256",
        "-M",
        "raspi3",
        "-serial",
        if (want_pty) "pty" else "stdio",
    });
    if (want_gdb) {
        try qemu_args.appendSlice([][]const u8{
            "-S",
            "-s",
        });
    }
    const run_qemu = b.addCommand(null, b.env_map, qemu_args.toSliceConst());
    qemu.dependOn(&run_qemu.step);
    run_qemu.step.dependOn(&exe.step);


    b.default_step.dependOn(&exe.step);
    b.installArtifact(exe);
}
