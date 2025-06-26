const common = @import("../common.zig");
const sdl3 = @import("sdl3");

pub const example_name = "Clear Screen";

pub fn init() !common.Context {
    const ctx = try common.init(example_name, .{});
    return ctx;
}

pub fn update(ctx: common.Context) !void {
    _ = ctx;
}

pub fn draw(ctx: common.Context) !void {

    // Get command buffer and swapchain texture.
    const cmd_buf = try ctx.device.acquireCommandBuffer();
    const swapchain_texture = try cmd_buf.waitAndAcquireSwapchainTexture(ctx.window);
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

    // Finally submit the command buffer.
    try cmd_buf.submit();
}

pub fn quit(ctx: common.Context) void {
    common.quit(ctx);
}
