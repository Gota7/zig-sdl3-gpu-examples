const common = @import("../common.zig");
const sdl3 = @import("sdl3");
const std = @import("std");

const vert_shader_name = "position_color.vert";
const frag_shader_name = "solid_color.frag";
const vert_shader_bin = @embedFile(vert_shader_name ++ ".spv");
const frag_shader_bin = @embedFile(frag_shader_name ++ ".spv");

comptime {
    common.ensureShadersCompatible(vert_shader_name, frag_shader_name);
}

const mode_names = [_][:0]const u8{
    "CW_CullNone",
    "CW_CullFront",
    "CW_CullBack",
    "CCW_CullNone",
    "CCW_CullFront",
    "CCW_CullBack",
};

var pipelines: [mode_names.len]sdl3.gpu.GraphicsPipeline = undefined;
var curr_mode: usize = 0;
var vertex_buffer_cw: sdl3.gpu.Buffer = undefined;
var vertex_buffer_ccw: sdl3.gpu.Buffer = undefined;

pub const example_name = "Cull Mode";

const PositionColorVertex = packed struct {
    position: @Vector(3, f32),
    color: @Vector(4, u8),
};

pub fn init() !common.Context {
    const ctx = try common.init(example_name, .{});
    curr_mode = 0;

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
    const input_state_buffers = [_]common.VertexInputStateBuffer{
        .{
            .cpu_backing = PositionColorVertex,
            .vert_shader_name = vert_shader_name,
        },
    };
    const vertex_buffer_descriptions = common.makeVertexBufferDescriptions(&input_state_buffers);
    const vertex_attributes = common.makeVertexAttributes(&input_state_buffers);
    var pipeline_create_info = sdl3.gpu.GraphicsPipelineCreateInfo{
        .target_info = .{
            .color_target_descriptions = &.{
                .{
                    .format = ctx.device.getSwapchainTextureFormat(ctx.window),
                },
            },
        },
        .vertex_input_state = .{
            .vertex_buffer_descriptions = &vertex_buffer_descriptions,
            .vertex_attributes = &vertex_attributes,
        },
        .vertex_shader = vert_shader,
        .fragment_shader = frag_shader,
    };
    for (0..pipelines.len) |i| {
        pipeline_create_info.rasterizer_state.cull_mode = @enumFromInt(i % 3);
        pipeline_create_info.rasterizer_state.front_face = if (i > 2) .clockwise else .counter_clockwise;
        pipelines[i] = try ctx.device.createGraphicsPipeline(pipeline_create_info);
        errdefer ctx.device.releaseGraphicsPipeline(pipelines[i]);
    }

    // Position-color data.
    const vertex_data = [_]PositionColorVertex{
        .{ .position = .{ -1, -1, 0 }, .color = .{ 255, 0, 0, 255 } },
        .{ .position = .{ 1, -1, 0 }, .color = .{ 0, 255, 0, 255 } },
        .{ .position = .{ 0, 1, 0 }, .color = .{ 0, 0, 255, 255 } },
        .{ .position = .{ 0, 1, 0 }, .color = .{ 255, 0, 0, 255 } },
        .{ .position = .{ 1, -1, 0 }, .color = .{ 0, 255, 0, 255 } },
        .{ .position = .{ -1, -1, 0 }, .color = .{ 0, 0, 255, 255 } },
    };

    // Divide by 2 as each buffer uses half the size.
    const vertex_data_size: u32 = @intCast(@sizeOf(@TypeOf(vertex_data)) / 2);

    // Create the vertex buffer.
    vertex_buffer_cw = try ctx.device.createBuffer(.{
        .usage = .{ .vertex = true },
        .size = vertex_data_size,
    });
    errdefer ctx.device.releaseBuffer(vertex_buffer_cw);
    vertex_buffer_ccw = try ctx.device.createBuffer(.{
        .usage = .{ .vertex = true },
        .size = vertex_data_size,
    });
    errdefer ctx.device.releaseBuffer(vertex_buffer_ccw);

    // Create a transfer buffer to upload the vertex data.
    const transfer_buffer = try ctx.device.createTransferBuffer(.{
        .usage = .upload,
        .size = vertex_data_size,
    });
    defer ctx.device.releaseTransferBuffer(transfer_buffer);
    const transfer_buffer_mapped = @as(
        *@TypeOf(vertex_data),
        @alignCast(@ptrCast(try ctx.device.mapTransferBuffer(transfer_buffer, false))),
    );
    transfer_buffer_mapped.* = vertex_data;
    ctx.device.unmapTransferBuffer(transfer_buffer);

    // Upload transfer data to the vertex buffer.
    const upload_cmd_buf = try ctx.device.acquireCommandBuffer();
    const copy_pass = upload_cmd_buf.beginCopyPass();
    copy_pass.uploadToBuffer(.{
        .transfer_buffer = transfer_buffer,
        .offset = 0,
    }, .{
        .buffer = vertex_buffer_cw,
        .offset = 0,
        .size = vertex_data_size,
    }, false);
    copy_pass.uploadToBuffer(.{
        .transfer_buffer = transfer_buffer,
        .offset = vertex_data_size,
    }, .{
        .buffer = vertex_buffer_ccw,
        .offset = 0,
        .size = vertex_data_size,
    }, false);
    copy_pass.end();
    try upload_cmd_buf.submit();

    try sdl3.log.log("Press Left/Right to switch between modes", .{});
    try sdl3.log.log("Current Mode: {s}", .{mode_names[curr_mode]});

    return ctx;
}

// Update contexts.
pub fn update(ctx: common.Context) !void {
    var changed = false;
    if (ctx.left_pressed) {
        if (curr_mode == 0) {
            curr_mode = pipelines.len - 1;
        } else curr_mode -= 1;
        changed = true;
    }
    if (ctx.right_pressed) {
        curr_mode += 1;
        curr_mode %= pipelines.len;
        changed = true;
    }
    if (changed)
        try sdl3.log.log("Current Mode: {s}", .{mode_names[curr_mode]});
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
        render_pass.bindGraphicsPipeline(pipelines[curr_mode]);

        // Bind the vertex buffers then draw the primitives.
        render_pass.setViewport(.{ .region = .{ .x = 0, .y = 0, .w = 320, .h = 480 } });
        render_pass.bindVertexBuffers(0, &.{
            .{ .buffer = vertex_buffer_cw, .offset = 0 },
        });
        render_pass.drawPrimitives(3, 1, 0, 0);
        render_pass.setViewport(.{ .region = .{ .x = 320, .y = 0, .w = 320, .h = 480 } });
        render_pass.bindVertexBuffers(0, &.{
            .{ .buffer = vertex_buffer_ccw, .offset = 0 },
        });
        render_pass.drawPrimitives(3, 1, 0, 0);
    }

    // Finally submit the command buffer.
    try cmd_buf.submit();
}

pub fn quit(ctx: common.Context) void {
    for (pipelines) |pipeline| {
        ctx.device.releaseGraphicsPipeline(pipeline);
    }

    ctx.device.releaseBuffer(vertex_buffer_cw);
    ctx.device.releaseBuffer(vertex_buffer_ccw);

    common.quit(ctx);
}
