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

var masker_pipeline: sdl3.gpu.GraphicsPipeline = undefined;
var maskee_pipeline: sdl3.gpu.GraphicsPipeline = undefined;
var vertex_buffer: sdl3.gpu.Buffer = undefined;
var depth_stencil_texture: sdl3.gpu.Texture = undefined;

pub const example_name = "Basic Stencil";

const PositionColorVertex = packed struct {
    position: @Vector(3, f32),
    color: @Vector(4, u8),
};

pub fn init() !common.Context {
    const ctx = try common.init(example_name, .{});

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

    // Get format for the depth stencil.
    const depth_stencil_format: sdl3.gpu.TextureFormat = if (ctx.device.textureSupportsFormat(.depth24_unorm_s8_uint, .two_dimensional, .{ .depth_stencil_target = true }))
        .depth24_unorm_s8_uint
    else if (ctx.device.textureSupportsFormat(.depth32_float_s8_uint, .two_dimensional, .{ .depth_stencil_target = true }))
        .depth32_float_s8_uint
    else {
        try sdl3.errors.set("Stencil formats not supported");
        unreachable;
    };

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
            .depth_stencil_format = depth_stencil_format,
        },
        .depth_stencil_state = .{
            .enable_stencil_test = true,
            .front_stencil_state = .{
                .compare = .never,
                .fail = .replace,
                .pass = .keep,
                .depth_fail = .keep,
            },
            .back_stencil_state = .{
                .compare = .never,
                .fail = .replace,
                .pass = .keep,
                .depth_fail = .keep,
            },
            .write_mask = 0xff,
        },
        .rasterizer_state = .{
            .cull_mode = .none,
            .fill_mode = .fill,
            .front_face = .counter_clockwise,
        },
        .vertex_input_state = .{
            .vertex_buffer_descriptions = &vertex_buffer_descriptions,
            .vertex_attributes = &vertex_attributes,
        },
        .vertex_shader = vert_shader,
        .fragment_shader = frag_shader,
    };
    masker_pipeline = try ctx.device.createGraphicsPipeline(pipeline_create_info);
    errdefer ctx.device.releaseGraphicsPipeline(masker_pipeline);

    // Setup maskee state.
    pipeline_create_info.depth_stencil_state = .{
        .enable_stencil_test = true,
        .front_stencil_state = .{
            .compare = .equal,
            .fail = .keep,
            .pass = .keep,
            .depth_fail = .keep,
        },
        .back_stencil_state = .{
            .compare = .never,
            .fail = .keep,
            .pass = .keep,
            .depth_fail = .keep,
        },
        .compare_mask = 0xff,
        .write_mask = 0,
    };
    maskee_pipeline = try ctx.device.createGraphicsPipeline(pipeline_create_info);
    errdefer ctx.device.releaseGraphicsPipeline(maskee_pipeline);

    // Create depth stencil texture.
    const window_size = try ctx.window.getSizeInPixels();
    depth_stencil_texture = try ctx.device.createTexture(.{
        .texture_type = .two_dimensional,
        .width = @intCast(window_size.width),
        .height = @intCast(window_size.height),
        .layer_count_or_depth = 1,
        .num_levels = 1,
        .sample_count = .no_multisampling,
        .format = depth_stencil_format,
        .usage = .{ .depth_stencil_target = true },
    });

    // Position-color data.
    const vertex_data = [_]PositionColorVertex{
        .{ .position = .{ -0.5, -0.5, 0 }, .color = .{ 255, 255, 0, 255 } },
        .{ .position = .{ 0.5, -0.5, 0 }, .color = .{ 255, 255, 0, 255 } },
        .{ .position = .{ 0, 0.5, 0 }, .color = .{ 255, 255, 0, 255 } },
        .{ .position = .{ -1, -1, 0 }, .color = .{ 255, 0, 0, 255 } },
        .{ .position = .{ 1, -1, 0 }, .color = .{ 0, 255, 0, 255 } },
        .{ .position = .{ 0, 1, 0 }, .color = .{ 0, 0, 255, 255 } },
    };
    const vertex_data_size: u32 = @intCast(@sizeOf(@TypeOf(vertex_data)));

    // Create the vertex buffer.
    vertex_buffer = try ctx.device.createBuffer(.{
        .usage = .{ .vertex = true },
        .size = vertex_data_size,
    });
    errdefer ctx.device.releaseBuffer(vertex_buffer);

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
        .buffer = vertex_buffer,
        .offset = 0,
        .size = vertex_data_size,
    }, false);
    copy_pass.end();
    try upload_cmd_buf.submit();

    return ctx;
}

// Update contexts.
pub fn update(ctx: common.Context) !void {
    _ = ctx;
}

pub fn draw(ctx: common.Context) !void {

    // Get command buffer and swapchain texture.
    const cmd_buf = try ctx.device.acquireCommandBuffer();
    const swapchain_texture = try cmd_buf.waitAndAcquireSwapchainTexture(ctx.window);
    if (swapchain_texture.texture) |texture| {

        // Start a render pass if the swapchain texture is available. Make sure to clear it.
        // Setup stencil state as well.
        const render_pass = cmd_buf.beginRenderPass(&.{
            sdl3.gpu.ColorTargetInfo{
                .texture = texture,
                .clear_color = .{ .a = 1 },
                .load = .clear,
            },
        }, .{
            .texture = depth_stencil_texture,
            .clear_depth = 0,
            .clear_stencil = 0,
            .load = .clear,
            .store = .do_not_care,
            .stencil_load = .clear,
            .stencil_store = .store,
            .cycle = false,
        });
        defer render_pass.end();

        // Bind the vertex buffers.
        render_pass.bindVertexBuffers(0, &.{
            .{ .buffer = vertex_buffer, .offset = 0 },
        });

        // Draw masker primitives.
        render_pass.setStencilReference(1);
        render_pass.bindGraphicsPipeline(masker_pipeline);
        render_pass.drawPrimitives(3, 1, 0, 0);

        // Draw maskee primitives.
        render_pass.setStencilReference(0);
        render_pass.bindGraphicsPipeline(maskee_pipeline);
        render_pass.drawPrimitives(3, 1, 3, 0);
    }

    // Finally submit the command buffer.
    try cmd_buf.submit();
}

pub fn quit(ctx: common.Context) void {
    ctx.device.releaseBuffer(vertex_buffer);
    ctx.device.releaseGraphicsPipeline(masker_pipeline);
    ctx.device.releaseGraphicsPipeline(maskee_pipeline);
    ctx.device.releaseTexture(depth_stencil_texture);

    common.quit(ctx);
}
