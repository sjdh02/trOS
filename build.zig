const builtin = @import("builtin");
const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    const want_gdb = b.option(bool, "gdb", "Build for QEMU gdb server") orelse false;
    const want_pty = b.option(bool, "pty", "Create a separate serial port path") orelse false;

    const mode = b.standardReleaseOptions();
    const exe = b.addStaticExecutable("trOS", "src/kernel.zig");
    exe.addAssemblyFile("src/asm/boot.S");
    exe.setBuildMode(mode);

    exe.setLinkerScriptPath("./linker.ld");
    // Use eabihf for freestanding arm code with hardware float support
    exe.setTarget(builtin.Arch{ .aarch64 = builtin.Arch.Arm64.v8 }, builtin.Os.freestanding, builtin.Abi.eabihf);

    const qemu = b.step("qemu", "run kernel in qemu");

    const qemu_path = if (builtin.os == builtin.Os.windows) "C:/Program Files/qemu/qemu-system-aarch64.exe" else "qemu-system-aarch64";
    const run_qemu = b.addSystemCommand([][]const u8 { qemu_path });
    run_qemu.addArg("-kernel");
    run_qemu.addArtifactArg(exe);
    run_qemu.addArgs([][]const u8{
        "-m",
        "256",
        "-M",
        "raspi3",
        "-serial",
        if (want_pty) "pty" else "stdio",
    });
    if (want_gdb) {
        run_qemu.addArgs([][]const u8{
            "-S",
            "-s",
        });
    }
    qemu.dependOn(&run_qemu.step);

    b.default_step.dependOn(&exe.step);
    b.installArtifact(exe);
}
