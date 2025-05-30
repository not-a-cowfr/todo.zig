const std = @import("std");

pub fn build(b: *std.Build) !void {
    var source_files = std.ArrayList([]const u8).init(b.allocator);
    defer source_files.deinit();

    var dir = try std.fs.cwd().openDir("src", .{ .iterate = true });
    defer dir.close();
    var walker = try dir.walk(b.allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.path, ".zig")) {
            try source_files.append(try b.allocator.dupe(u8, b.fmt("src/{s}", .{entry.path})));
        }
    }

    var handlers = std.ArrayList([]const u8).init(b.allocator);
    defer handlers.deinit();

    var imports = std.ArrayList([]const u8).init(b.allocator);
    defer imports.deinit();

    var import_set = std.StringHashMap(void).init(b.allocator);
    defer import_set.deinit();

    for (source_files.items) |file_path| {
        const source = try std.fs.cwd().readFileAlloc(b.allocator, file_path, 1024 * 1024 * 8);
        defer b.allocator.free(source);

        var module_name = std.fs.path.basename(file_path);
        module_name = module_name[0 .. module_name.len - 4];

        var lines = std.mem.splitScalar(u8, source, '\n');
        while (lines.next()) |line| {
            if (std.mem.indexOf(u8, line, "// @EventHandler(")) |start| {
                const event_type_end = std.mem.indexOf(u8, line[start + 16 ..], ")") orelse continue;
                const event_type = line[start + 17 .. start + 16 + event_type_end];

                while (lines.next()) |next_line| {
                    if (std.mem.indexOf(u8, next_line, "pub fn ")) |fn_start| {
                        const fn_name_start = fn_start + 7;
                        const fn_name_end = std.mem.indexOf(u8, next_line[fn_name_start..], "(") orelse continue;
                        const fn_name = next_line[fn_name_start .. fn_name_start + fn_name_end];
                        try handlers.append(try std.fmt.allocPrint(
                            b.allocator,
                            "try dispatcher.register({s}.{s}, events.EventType.{s});",
                            .{ module_name, fn_name, event_type },
                        ));

                        if (!import_set.contains(module_name)) {
                            try import_set.put(module_name, {});
                            try imports.append(try std.fmt.allocPrint(
                                b.allocator,
                                "const {s} = @import(\"{s}.zig\");",
                                .{ module_name, module_name },
                            ));
                        }

                        break;
                    }
                }
            }
        }
    }

    const imports_string = try std.mem.join(b.allocator, "\n", imports.items);
    const regsiters_string = try std.mem.join(b.allocator, "\n\t", handlers.items);
    const handlers_code = try std.fmt.allocPrint(b.allocator,
        \\const events = @import("events.zig");
        \\const std = @import("std");
        \\
        \\{s}
        \\
        \\pub fn init() !events.EventDispatcher {{
        \\  var allocator = std.heap.GeneralPurposeAllocator(.{{}}){{}};
        \\  defer _ = allocator.deinit();
        \\  const alloc = allocator.allocator();
        \\
        \\  var dispatcher = events.EventDispatcher.init(alloc);
        \\  
        \\  {s}
        \\
        \\  return dispatcher;
        \\}}
    , .{ imports_string, regsiters_string });
    defer b.allocator.free(handlers_code);

    const gen_path = b.pathJoin(&.{ "src", "dispatch_gen.zig" });
    try std.fs.cwd().writeFile(.{
        .data = handlers_code,
        .sub_path = gen_path,
    });

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "output",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });
    const raylib = raylib_dep.module("raylib");
    const raygui = raylib_dep.module("raygui");
    const raylib_artifact = raylib_dep.artifact("raylib");

    exe.linkLibrary(raylib_artifact);
    exe.root_module.addImport("raylib", raylib);
    exe.root_module.addImport("raygui", raygui);

    // const models_mod = b.addModule("models", .{ .root_source_file = b.path("src/models.zig") });
    // exe.root_module.addImport("models", models_mod);

    // const events_mod = b.addModule("events", .{
    //     .root_source_file = b.path("src/events.zig"),
    //     .imports = &.{.{ .name = "models", .module = models_mod }},
    // });
    // exe.root_module.addImport("events", events_mod);

    // const handlers_module = b.createModule(.{
    //     .root_source_file = b.path(gen_path),
    //     .imports = &.{.{ .name = "events", .module = events_mod }},
    // });
    // exe.root_module.addImport("dispatch_gen", handlers_module);

    // for (source_files.items) |file_path| {
    //     const module_name = std.fs.path.basename(file_path)[0 .. std.fs.path.basename(file_path).len - 4];
    //     exe.root_module.addImport(module_name, b.createModule(.{
    //         .root_source_file = b.path(file_path),
    //     }));
    // }

    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
