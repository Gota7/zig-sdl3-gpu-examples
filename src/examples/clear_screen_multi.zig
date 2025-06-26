const common = @import("../common.zig");
const sdl3 = @import("sdl3");

pub const example_name = "Clear Screen Multi-Window";
var window: sdl3.video.Window = undefined;

pub fn init() !common.Context {
    const ctx = try common.init(example_name, .{});
    window = try sdl3.video.Window.init("Clear Screen Multi-Window 2", 640, 480, .{});
    try ctx.device.claimWindow(window);
    return ctx;
}

pub fn update(ctx: common.Context) !void {
    _ = ctx;
}

pub fn draw(ctx: common.Context) !void {

    // Get command buffer and swapchain texture.
    const cmd_buf = try ctx.device.acquireCommandBuffer();
    var swapchain_texture = try cmd_buf.waitAndAcquireSwapchainTexture(ctx.window);
    if (swapchain_texture.texture) |texture| {

        // Start a render pass if the swapchain texture is available. Make sure to clear it.
        const render_pass = cmd_buf.beginRenderPass(&.{
            sdl3.gpu.ColorTargetInfo{
                .texture = texture,
                .clear_color = .{ .r = 0.3, .g = 0.3, .b = 0.5, .a = 1 },
                .load = .clear,
            },
        }, null);
        defer render_pass.end();
    }
    swapchain_texture = try cmd_buf.waitAndAcquireSwapchainTexture(window);
    if (swapchain_texture.texture) |texture| {

        // Start a render pass if the swapchain texture is available. Make sure to clear it.
        const render_pass = cmd_buf.beginRenderPass(&.{
            sdl3.gpu.ColorTargetInfo{
                .texture = texture,
                .clear_color = .{ .r = 1, .g = 0.5, .b = 0.6, .a = 1 },
                .load = .clear,
            },
        }, null);
        defer render_pass.end();
    }

    // Finally submit the command buffer.
    try cmd_buf.submit();
}

pub fn quit(ctx: common.Context) void {
    ctx.device.releaseWindow(window);
    window.deinit();
    common.quit(ctx);
}
