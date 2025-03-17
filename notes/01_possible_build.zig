const std = @import("std");

pub fn build(b: *std.build.Builder) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // --- Building the core BEAM VM ---
    // This section defines how to build the Erlang Runtime System (ERTS),
    // which is the core of Erlang and primarily written in C.

    const erts_c_sources = &.{
        "erts/main/main.c",
        "erts/emulator/beam/beam_main.c",
        "erts/emulator/beam/erl_vm.c",
        // ... add many more C source files from the erts directory ...
        // This list needs to be comprehensive based on the Erlang/OTP source.
    };

    const beam_vm = b.addExecutable(.{
        .name = "beam.smp", // The name of the BEAM executable
        .root_source_file = .{ .path = erts_c_sources[0] }, // Placeholder, the actual root might be different
        .sources = erts_c_sources,
        .target = target,
        .optimize = optimize,
    });

    // Adding include paths for C headers. These paths need to point to
    // the relevant directories within the Erlang/OTP source tree.
    beam_vm.addIncludePath(.{ .path = "erts/include" });
    beam_vm.addIncludePath(.{ .path = "erts/emulator/beam" });
    // ... add other necessary include paths from the Erlang/OTP source ...

    // Defining preprocessor definitions that might be required by the C code.
    // These often mimic the settings done by the traditional 'configure' script.
    beam_vm.define("HAVE_CONFIG_H", "1");
    // ... add other necessary preprocessor definitions ...

    // Linking against system libraries that the BEAM VM depends on.
    beam_vm.linkLibC(); // Link against the standard C library
    beam_vm.linkSystemLibrary("pthread"); // For POSIX threads
    beam_vm.linkSystemLibrary("m"); // For mathematical functions
    beam_vm.linkSystemLibrary("z"); // For zlib (compression) - initial MVP might use system lib
    beam_vm.linkSystemLibrary("ssl"); // For openssl (security) - initial MVP might use system lib
    // ... add other system libraries as needed (e.g., 'dl' for dynamic linking) ...

    // Create a build step to build the BEAM VM.
    const beam_vm_step = beam_vm.step;

    // --- Compiling Erlang Libraries ---
    // This section outlines the (conceptual) steps for compiling the Erlang
    // source files (.erl) that make up the OTP libraries. This will likely
    // require a bootstrapping process.

    // Placeholder for obtaining the path to our (eventually Zig-built) erlc.
    // In the initial stages, this might point to a pre-existing Erlang installation's erlc.
    const erlc_path_command = b.addSystemCommand(.{
        .name = "get_erlc_path",
        .steps = &.{
            .{ .command = &[_]const u8{ "echo", "./path/to/our/erlc" } }, // Replace with actual logic to find/build erlc
        },
    });
    const erlc_executable = erlc_path_command.getOutputExecutable();

    // Example for compiling the 'kernel' library. We'll need to do this for
    // 'stdlib' and other OTP applications as well.
    const kernel_sources = b.addDirectory(.{ .path = "lib/kernel/src" });
    const kernel_output_dir = b.installArtifact(kernel_sources);

    const compile_kernel = b.addSystemCommand(.{
        .name = "compile_kernel",
        .cwd = kernel_output_dir,
        .steps = &.{
            .{ .command = &[_]const u8{ erlc_executable, "*.erl" } },
        },
    });
    compile_kernel.dependOn(&beam_vm_step); // Ensure BEAM is built before compiling Erlang code

    // --- Handling Dependencies (Example of using a Zig package later) ---
    // This section shows how we might integrate a Zig package for a dependency
    // like zlib in the future, instead of relying on the system library.

    // const zlib_package = b.dependency("zlib-zig", .{ .version = "some_version" });
    // beam_vm.addPackage(zlib_package);

    // --- Final Build Step ---
    // This defines the main build step that users will invoke.
    const package = b.addPackage(.{
        .name = "erlang_otp",
        .version = "0.1.0", // Example version
    });

    const install_step = b.addInstall();
    install_step.addPackage(package);
    install_step.addArtifact(beam_vm);
    // ... add other artifacts to install (e.g., compiled Erlang libraries) ...

    const run_step = b.addRunArtifact(beam_vm);
    run_step.step.dependOn(&install_step.step);

    b.default_step.dependOn(&run_step.step);
}

