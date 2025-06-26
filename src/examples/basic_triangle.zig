const common = @import("../common.zig");
const sdl3 = @import("sdl3");

const vert_shader_name = "raw_triangle.vert";
const frag_shader_name = "solid_color.frag";
const vert_shader_bin = @embedFile(vert_shader_name ++ ".spv");
const frag_shader_bin = @embedFile(frag_shader_name ++ ".spv");

comptime {
    common.ensureShadersCompatible(vert_shader_name, frag_shader_name);
}

var fill_pipeline: sdl3.gpu.GraphicsPipeline = undefined;
var line_pipeline: sdl3.gpu.GraphicsPipeline = undefined;
var wire_frame: bool = undefined;
var small_viewport: bool = undefined;
var scissor_rect: bool = undefined;

pub const example_name = "Basic Triangle";

pub fn init() !common.Context {
    const ctx = try common.init(example_name, .{});

    // Defaults for globals.
    wire_frame = false;
    small_viewport = false;
    scissor_rect = false;

    // Create the shaders.
    const vert_shader = try common.loadShader(
        ctx.device,
        .vertex,
        vert_shader_bin,
        0,
        0,
        0,
        0,
    );
    defer ctx.device.releaseShader(vert_shader);
    const frag_shader = try common.loadShader(
        ctx.device,
        .vertex,
        frag_shader_bin,
        0,
        0,
        0,
        0,
    );
    defer ctx.device.releaseShader(frag_shader);

    // Create the pipelines.
    var pipeline_create_info = sdl3.gpu.GraphicsPipelineCreateInfo{
        .target_info = .{
            .color_target_descriptions = &.{
                .{
                    .format = ctx.device.getSwapchainTextureFormat(ctx.window),
                },
            },
        },
        .vertex_shader = vert_shader,
        .fragment_shader = frag_shader,
    };
    fill_pipeline = try ctx.device.createGraphicsPipeline(pipeline_create_info);
    errdefer ctx.device.releaseGraphicsPipeline(fill_pipeline);
    pipeline_create_info.rasterizer_state.fill_mode = .line;
    line_pipeline = try ctx.device.createGraphicsPipeline(pipeline_create_info);
    errdefer ctx.device.releaseGraphicsPipeline(line_pipeline);

    try sdl3.log.log("Press left to toggle wireframe", .{});
    try sdl3.log.log("Press down to toggle small viewport", .{});
    try sdl3.log.log("Press right to toggle scissor rect", .{});

    return ctx;
}

// Update contexts.
pub fn update(ctx: common.Context) !void {
    if (ctx.left_pressed)
        wire_frame = !wire_frame;
    if (ctx.down_pressed)
        small_viewport = !small_viewport;
    if (ctx.right_pressed)
        scissor_rect = !scissor_rect;
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
                .clear_color = .{ .a = 1 },
                .load = .clear,
            },
        }, null);
        defer render_pass.end();

        // Bind the graphics pipeline we chose earlier.
        render_pass.bindGraphicsPipeline(if (wire_frame) line_pipeline else fill_pipeline);
        if (small_viewport)
            render_pass.setViewport(.{
                .region = .{
                    .x = 100,
                    .y = 120,
                    .w = 320,
                    .h = 240,
                },
                .min_depth = 0.1,
                .max_depth = 1,
            });

        // Apply scissoring.
        if (scissor_rect)
            render_pass.setScissor(.{
                .x = 320,
                .y = 240,
                .w = 320,
                .h = 240,
            });

        // Draw a single triangle. Even though there is no vertex data, the vertex shader has the vertex info for us so it doesn't matter.
        render_pass.drawPrimitives(3, 1, 0, 0);
    }

    // Finally submit the command buffer.
    try cmd_buf.submit();
}

pub fn quit(ctx: common.Context) void {
    ctx.device.releaseGraphicsPipeline(fill_pipeline);
    ctx.device.releaseGraphicsPipeline(line_pipeline);

    common.quit(ctx);
}
