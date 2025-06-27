const common = @import("../common.zig");
const sdl3 = @import("sdl3");
const std = @import("std");

const vert_shader_name = "textured_quad.vert";
const frag_shader_name = "textured_quad.frag";
const vert_shader_bin = @embedFile(vert_shader_name ++ ".spv");
const frag_shader_bin = @embedFile(frag_shader_name ++ ".spv");

const ravioli_bmp = @embedFile("../images/ravioli.bmp");

comptime {
    common.ensureShadersCompatible(vert_shader_name, frag_shader_name);
}

const sampler_names = [_][]const u8{
    "PointClamp",
    "PointWrap",
    "LinearClamp",
    "LinearWrap",
    "AnisotropicClamp",
    "AnisotropicWrap",
};

var pipeline: sdl3.gpu.GraphicsPipeline = undefined;
var vertex_buffer: sdl3.gpu.Buffer = undefined;
var index_buffer: sdl3.gpu.Buffer = undefined;
var texture: sdl3.gpu.Texture = undefined;
var samplers: [sampler_names.len]sdl3.gpu.Sampler = undefined;
var curr_sampler: usize = undefined;

pub const example_name = "Textured Quad";

const PositionTextureVertex = packed struct {
    position: @Vector(3, f32),
    uv: @Vector(2, f32),
};

pub fn init() !common.Context {
    const ctx = try common.init(example_name, .{});
    curr_sampler = 0;

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
        1,
        0,
        0,
        0,
    );
    defer ctx.device.releaseShader(frag_shader);

    // Load the image.
    const image_data = try common.loadImage(ravioli_bmp);
    defer image_data.deinit();

    // Create the pipelines.
    const input_state_buffers = [_]common.VertexInputStateBuffer{
        .{
            .cpu_backing = PositionTextureVertex,
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

    // Create samplers.
    samplers[0] = try ctx.device.createSampler(.{
        .min_filter = .nearest,
        .mag_filter = .nearest,
        .mipmap_mode = .nearest,
        .address_mode_u = .clamp_to_edge,
        .address_mode_v = .clamp_to_edge,
        .address_mode_w = .clamp_to_edge,
    });
    samplers[1] = try ctx.device.createSampler(.{
        .min_filter = .nearest,
        .mag_filter = .nearest,
        .mipmap_mode = .nearest,
        .address_mode_u = .repeat,
        .address_mode_v = .repeat,
        .address_mode_w = .repeat,
    });
    samplers[2] = try ctx.device.createSampler(.{
        .min_filter = .linear,
        .mag_filter = .linear,
        .mipmap_mode = .linear,
        .address_mode_u = .clamp_to_edge,
        .address_mode_v = .clamp_to_edge,
        .address_mode_w = .clamp_to_edge,
    });
    samplers[3] = try ctx.device.createSampler(.{
        .min_filter = .linear,
        .mag_filter = .linear,
        .mipmap_mode = .linear,
        .address_mode_u = .repeat,
        .address_mode_v = .repeat,
        .address_mode_w = .repeat,
    });
    samplers[4] = try ctx.device.createSampler(.{
        .min_filter = .linear,
        .mag_filter = .linear,
        .mipmap_mode = .linear,
        .address_mode_u = .clamp_to_edge,
        .address_mode_v = .clamp_to_edge,
        .address_mode_w = .clamp_to_edge,
        .max_anisotropy = 4,
    });
    samplers[5] = try ctx.device.createSampler(.{
        .min_filter = .linear,
        .mag_filter = .linear,
        .mipmap_mode = .linear,
        .address_mode_u = .repeat,
        .address_mode_v = .repeat,
        .address_mode_w = .repeat,
        .max_anisotropy = 4,
    });

    // Position-color data.
    const vertex_data = [_]PositionTextureVertex{
        .{ .position = .{ -1, 1, 0 }, .uv = .{ 0, 0 } },
        .{ .position = .{ 1, 1, 0 }, .uv = .{ 4, 0 } },
        .{ .position = .{ 1, -1, 0 }, .uv = .{ 4, 4 } },
        .{ .position = .{ -1, -1, 0 }, .uv = .{ 0, 4 } },
    };
    const vertex_data_size: u32 = @intCast(@sizeOf(@TypeOf(vertex_data)));

    // Index-buffer data.
    const index_data = [_]u16{ 0, 1, 2, 0, 2, 3 };
    const index_data_size: u32 = @intCast(@sizeOf(@TypeOf(index_data)));

    // Create the vertex buffer.
    vertex_buffer = try ctx.device.createBuffer(.{
        .usage = .{ .vertex = true },
        .size = vertex_data_size,
    });
    errdefer ctx.device.releaseBuffer(vertex_buffer);
    ctx.device.setBufferName(vertex_buffer, "Ravioli Vertex Buffer");

    // Create the index buffer.
    index_buffer = try ctx.device.createBuffer(.{
        .usage = .{ .index = true },
        .size = index_data_size,
    });
    errdefer ctx.device.releaseBuffer(index_buffer);

    // Create texture.
    texture = try ctx.device.createTexture(.{
        .texture_type = .two_dimensional,
        .format = .r8g8b8a8_unorm,
        .width = @intCast(image_data.getWidth()),
        .height = @intCast(image_data.getHeight()),
        .layer_count_or_depth = 1,
        .num_levels = 1,
        .usage = .{ .sampler = true },
    });
    errdefer ctx.device.releaseTexture(texture);
    ctx.device.setTextureName(texture, "Ravioli Texture");

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

    // Create a transfer buffer to upload the image data.
    const texture_transfer_buffer = try ctx.device.createTransferBuffer(.{
        .usage = .upload,
        .size = @intCast(image_data.getWidth() * image_data.getHeight() * 4),
    });
    defer ctx.device.releaseTransferBuffer(texture_transfer_buffer);
    const texture_transfer_buffer_mapped = try ctx.device.mapTransferBuffer(texture_transfer_buffer, false);
    @memcpy(texture_transfer_buffer_mapped, image_data.getPixels().?);
    ctx.device.unmapTransferBuffer(texture_transfer_buffer);

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
    copy_pass.uploadToTexture(
        .{
            .transfer_buffer = texture_transfer_buffer,
            .offset = 0,
        },
        .{
            .texture = texture,
            .width = @intCast(image_data.getWidth()),
            .height = @intCast(image_data.getHeight()),
            .depth = 1,
        },
        false,
    );
    copy_pass.end();
    try upload_cmd_buf.submit();

    try sdl3.log.log("Press Left/Right to switch between sampler states", .{});
    try sdl3.log.log("Setting sampler state to: {s}", .{sampler_names[curr_sampler]});

    return ctx;
}

// Update contexts.
pub fn update(ctx: common.Context) !void {
    var changed: bool = false;
    if (ctx.left_pressed) {
        if (curr_sampler == 0) {
            curr_sampler = samplers.len - 1;
        } else curr_sampler -= 1;
        changed = true;
    }
    if (ctx.right_pressed) {
        curr_sampler += 1;
        curr_sampler %= samplers.len;
        changed = true;
    }
    if (changed)
        try sdl3.log.log("Setting sampler state to: {s}", .{sampler_names[curr_sampler]});
}

pub fn draw(ctx: common.Context) !void {

    // Get command buffer and swapchain texture.
    const cmd_buf = try ctx.device.acquireCommandBuffer();
    const swapchain_texture = try cmd_buf.waitAndAcquireSwapchainTexture(ctx.window);
    if (swapchain_texture.texture) |swapchain_texture_val| {

        // Start a render pass if the swapchain texture is available. Make sure to clear it.
        const render_pass = cmd_buf.beginRenderPass(&.{
            sdl3.gpu.ColorTargetInfo{
                .texture = swapchain_texture_val,
                .clear_color = .{ .a = 1 },
                .load = .clear,
            },
        }, null);
        defer render_pass.end();

        // Bind the graphics pipeline we chose earlier.
        render_pass.bindGraphicsPipeline(pipeline);

        // Bind the buffers then draw the primitives.
        render_pass.bindVertexBuffers(0, &.{
            .{ .buffer = vertex_buffer, .offset = 0 },
        });
        render_pass.bindIndexBuffer(.{ .buffer = index_buffer, .offset = 0 }, .indices_16bit);
        render_pass.bindFragmentSamplers(0, &.{.{ .texture = texture, .sampler = samplers[curr_sampler] }});
        render_pass.drawIndexedPrimitives(6, 1, 0, 0, 0);
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
