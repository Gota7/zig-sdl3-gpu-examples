const common = @import("common.zig");
const sdl3 = @import("sdl3");
const std = @import("std");

// Attribute verification.
comptime {
    // common.ensureNoDuplicateSlots() catch |err| @compileError(std.fmt.comptimePrint("{e}", .{err}));
}

/// Example structure.
const Example = struct {
    name: []const u8,
    init: *const fn () anyerror!common.Context,
    update: *const fn (ctx: common.Context) anyerror!void,
    draw: *const fn (ctx: common.Context) anyerror!void,
    quit: *const fn (ctx: common.Context) void,
};

/// Automatically create an example structure from an example file.
fn makeExample(example: anytype) Example {
    return .{
        .name = example.example_name,
        .init = &example.init,
        .update = &example.update,
        .draw = &example.draw,
        .quit = &example.quit,
    };
}

/// List of example files.
const examples = [_]Example{
    makeExample(@import("examples/clear_screen.zig")),
    makeExample(@import("examples/clear_screen_multi.zig")),
    makeExample(@import("examples/basic_triangle.zig")),
    makeExample(@import("examples/basic_vertex_buffer.zig")),
    makeExample(@import("examples/cull_mode.zig")),
    makeExample(@import("examples/basic_stencil.zig")),
    makeExample(@import("examples/instanced_indexed.zig")),
    makeExample(@import("examples/textured_quad.zig")),
};

/// Example index to start with.
const starting_example = 0;

/// An example function to handle errors from SDL.
///
/// ## Function Parameters
/// * `err`: A slice to an error message, or `null` if the error message is not known.
///
/// ## Remarks
/// Remember that the error callback is thread-local, thus you need to set it for each thread!
fn sdlErr(
    err: ?[]const u8,
) void {
    if (err) |val| {
        std.debug.print("******* [Error! {s}] *******\n", .{val});
    } else {
        std.debug.print("******* [Unknown Error!] *******\n", .{});
    }
}

/// An example function to log with SDL.
///
/// ## Function Parameters
/// * `user_data`: User data provided to the logging function.
/// * `category`: Which category SDL is logging under, for example "video".
/// * `priority`: Which priority the log message is.
/// * `message`: Actual message to log. This should not be `null`.
fn sdlLog(
    user_data: ?*anyopaque,
    category: ?sdl3.log.Category,
    priority: ?sdl3.log.Priority,
    message: [:0]const u8,
) void {
    _ = user_data;
    const category_str: ?[]const u8 = if (category) |val| switch (val) {
        .application => "Application",
        .errors => "Errors",
        .assert => "Assert",
        .system => "System",
        .audio => "Audio",
        .video => "Video",
        .render => "Render",
        .input => "Input",
        .testing => "Testing",
        .gpu => "Gpu",
        else => null,
    } else null;
    const priority_str: [:0]const u8 = if (priority) |val| switch (val) {
        .trace => "Trace",
        .verbose => "Verbose",
        .debug => "Debug",
        .info => "Info",
        .warn => "Warn",
        .err => "Error",
        .critical => "Critical",
    } else "Unknown";
    if (category_str) |val| {
        std.debug.print("[{s}:{s}] {s}\n", .{ val, priority_str, message });
    } else {
        std.debug.print("[Custom_{?}:{s}] {s}\n", .{ category, priority_str, message });
    }
}

/// Main entry point of our code.
///
/// Note: For most actual projects, you most likely want a callbacks setup.
/// See the template for details.
pub fn main() !void {

    // Setup logging.
    sdl3.errors.error_callback = &sdlErr;
    sdl3.log.setAllPriorities(.info);
    sdl3.log.setLogOutputFunction(anyopaque, sdlLog, null);

    // Setup SDL3.
    defer sdl3.shutdown();
    const init_flags = sdl3.InitFlags{ .video = true, .gamepad = true };
    try sdl3.init(init_flags);
    defer sdl3.quit(init_flags);

    // Setup initial example.
    var example_index: usize = starting_example;
    var ctx = try examples[example_index].init();
    defer examples[example_index].quit(ctx);
    try sdl3.log.log("Loaded \"{s}\" Example", .{examples[example_index].name});

    // Main loop.
    var quit = false;
    var goto_index: ?usize = null;
    var last_time: f32 = 0;
    const can_draw = true;
    while (!quit) {
        ctx.left_pressed = false;
        ctx.right_pressed = false;
        ctx.down_pressed = false;
        ctx.up_pressed = false;

        // Handle events.
        while (sdl3.events.poll()) |event| {
            switch (event) {
                .quit, .terminating => quit = true,
                .key_down => |val| if (val.key) |key| switch (key) {
                    .d => goto_index = (example_index + 1) % examples.len,
                    .a => goto_index = if (example_index == 0) examples.len - 1 else example_index - 1,
                    .left => ctx.left_pressed = true,
                    .right => ctx.right_pressed = true,
                    .down => ctx.down_pressed = true,
                    .up => ctx.up_pressed = true,
                    else => {},
                },
                else => {},
            }
        }

        // Early quit.
        if (quit)
            break;

        // Switch index.
        if (goto_index) |index| {
            examples[example_index].quit(ctx);
            example_index = index;
            goto_index = null;
            ctx = try examples[index].init();
            try sdl3.log.log("Loaded {s}", .{examples[example_index].name});
        }

        // Delta time calculation.
        const new_time = @as(f32, @floatFromInt(sdl3.timer.getMillisecondsSinceInit())) / 1000;
        const delta_time = new_time - last_time;
        last_time = new_time;
        ctx.delta_time = delta_time;

        // Update and draw current example.
        try examples[example_index].update(ctx);
        if (can_draw)
            try examples[example_index].draw(ctx);
    }
}
