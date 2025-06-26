const common = @import("../common.zig");
const sdl3 = @import("sdl3");
const std = @import("std");

const vert_shader_name = "position_color_instanced.vert";
const frag_shader_name = "solid_color.frag";
const vert_shader_bin = @embedFile(vert_shader_name ++ ".spv");
const frag_shader_bin = @embedFile(frag_shader_name ++ ".spv");

comptime {
    common.ensureShadersCompatible(vert_shader_name, frag_shader_name);
}

var pipeline: sdl3.gpu.GraphicsPipeline = undefined;
var vertex_buffer: sdl3.gpu.Buffer = undefined;
var index_buffer: sdl3.gpu.Buffer = undefined;
var use_vertex_offset: bool = undefined;
var use_index_offset: bool = undefined;
var use_index_buffer: bool = undefined;

pub const example_name = "Instanced Indexed";

const PositionColorVertex = packed struct {
    position: @Vector(3, f32),
    color: @Vector(4, u8),
};

pub fn init() !common.Context {
    const ctx = try common.init(example_name, .{});

    // Clear settings.
    use_vertex_offset = false;
    use_index_offset = false;
    use_index_buffer = false;

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
    const pipeline_create_info = sdl3.gpu.GraphicsPipelineCreateInfo{
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
    pipeline = try ctx.device.createGraphicsPipeline(pipeline_create_info);
    errdefer ctx.device.releaseGraphicsPipeline(pipeline);

    // Position-color data.
    const vertex_data = [_]PositionColorVertex{
        .{ .position = .{ -1, -1, 0 }, .color = .{ 255, 0, 0, 255 } },
        .{ .position = .{ 1, -1, 0 }, .color = .{ 0, 255, 0, 255 } },
        .{ .position = .{ 0, 1, 0 }, .color = .{ 0, 0, 255, 255 } },

        .{ .position = .{ -1, -1, 0 }, .color = .{ 255, 165, 0, 255 } },
        .{ .position = .{ 1, -1, 0 }, .color = .{ 0, 128, 0, 255 } },
        .{ .position = .{ 0, 1, 0 }, .color = .{ 0, 255, 255, 255 } },

        .{ .position = .{ -1, -1, 0 }, .color = .{ 255, 255, 255, 255 } },
        .{ .position = .{ 1, -1, 0 }, .color = .{ 255, 255, 255, 255 } },
        .{ .position = .{ 0, 1, 0 }, .color = .{ 255, 255, 255, 255 } },
    };
    const vertex_data_size: u32 = @intCast(@sizeOf(@TypeOf(vertex_data)));

    // Index-buffer data.
    const index_data = [_]u16{ 0, 1, 2, 3, 4, 5 };
    const index_data_size: u32 = @intCast(@sizeOf(@TypeOf(index_data)));

    // Create the vertex buffer.
    vertex_buffer = try ctx.device.createBuffer(.{
        .usage = .{ .vertex = true },
        .size = vertex_data_size,
    });
    errdefer ctx.device.releaseBuffer(vertex_buffer);

    // Create the index buffer.
    index_buffer = try ctx.device.createBuffer(.{
        .usage = .{ .index = true },
        .size = index_data_size,
    });
    errdefer ctx.device.releaseBuffer(index_buffer);

    // Create a transfer buffer to upload the vertex data.
    const transfer_buffer = try ctx.device.createTransferBuffer(.{
        .usage = .upload,
        .size = vertex_data_size + index_data_size,
    });
    defer ctx.device.releaseTransferBuffer(transfer_buffer);
    const transfer_buffer_mapped = @as(
        *@TypeOf(vertex_data),
        @alignCast(@ptrCast(try ctx.device.mapTransferBuffer(transfer_buffer, false))),
    );
    transfer_buffer_mapped.* = vertex_data;
    @as(*@TypeOf(index_data), @ptrFromInt(@intFromPtr(transfer_buffer_mapped) + vertex_data_size)).* = index_data;
    ctx.device.unmapTransferBuffer(transfer_buffer);

    // Upload transfer data to the vertex buffer.
    const upload_cmd_buf = try ctx.device.acquireCommandBuffer();
    const copy_pass = upload_cmd_buf.beginCopyPass();
    copy_pass.uploadToBuffer(.{
        .transfer_buffer = transfer_buffer,
        .offset = 0,
    }, .{
        .buffer = vertex_buffer,
        .offset = 0,
        .size = vertex_data_size,
    }, false);
    copy_pass.uploadToBuffer(.{
        .transfer_buffer = transfer_buffer,
        .offset = vertex_data_size,
    }, .{
        .buffer = index_buffer,
        .offset = 0,
        .size = index_data_size,
    }, false);
    copy_pass.end();
    try upload_cmd_buf.submit();

    try sdl3.log.log("Press Left to toggle vertex offset, Right to toggle index offset, and Up to use index buffer", .{});

    return ctx;
}

// Update contexts.
pub fn update(ctx: common.Context) !void {
    if (ctx.left_pressed) {
        use_vertex_offset = !use_vertex_offset;
        try sdl3.log.log("Using vertex offset: {}", .{use_vertex_offset});
    }
    if (ctx.right_pressed) {
        use_index_offset = !use_index_offset;
        try sdl3.log.log("Using index offset: {}", .{use_index_offset});
    }
    if (ctx.up_pressed) {
        use_index_buffer = !use_index_buffer;
        try sdl3.log.log("Using index buffer: {}", .{use_index_buffer});
    }
}

pub fn draw(ctx: common.Context) !void {
    const vertex_offset: u32 = if (use_vertex_offset) 3 else 0;
    const index_offset: u32 = if (use_index_offset) 3 else 0;

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
        render_pass.bindGraphicsPipeline(pipeline);

        // Bind the vertex buffers then draw the primitives.
        render_pass.bindVertexBuffers(0, &.{
            .{ .buffer = vertex_buffer, .offset = 0 },
        });
        if (use_index_buffer) {
            render_pass.bindIndexBuffer(.{ .buffer = index_buffer, .offset = 0 }, .indices_16bit);
            render_pass.drawIndexedPrimitives(3, 16, index_offset, @intCast(vertex_offset), 0);
        } else {
            render_pass.drawPrimitives(3, 16, vertex_offset, 0);
        }
    }

    // Finally submit the command buffer.
    try cmd_buf.submit();
}

pub fn quit(ctx: common.Context) void {
    ctx.device.releaseBuffer(vertex_buffer);
    ctx.device.releaseBuffer(index_buffer);
    ctx.device.releaseGraphicsPipeline(pipeline);

    common.quit(ctx);
}
