const attributes = @import("shaders/attributes.zig");
const common = @import("shaders/common.zig");
const sdl3 = @import("sdl3");
const std = @import("std");

pub const Context = struct {
    device: sdl3.gpu.Device,
    window: sdl3.video.Window,
    delta_time: f32 = 0,
    left_pressed: bool = false,
    right_pressed: bool = false,
    down_pressed: bool = false,
    up_pressed: bool = false,
};

pub fn init(example_name: [:0]const u8, window_flags: sdl3.video.WindowFlags) !Context {

    // Get our GPU device that supports SPIR-V.
    const device = try sdl3.gpu.Device.init(.{ .spirv = true }, false, null);
    errdefer device.deinit();

    // Make our demo window.
    const window = try sdl3.video.Window.init(example_name, 640, 480, window_flags);
    errdefer window.deinit();

    // Generate swapchain for window.
    try device.claimWindow(window);
    return .{
        .device = device,
        .window = window,
    };
}

pub fn quit(ctx: Context) void {
    ctx.device.releaseWindow(ctx.window);
    ctx.window.deinit();
    ctx.device.deinit();
}

pub fn loadImage(
    bmp: []const u8,
) !sdl3.surface.Surface {
    const image_data_raw = try sdl3.surface.Surface.initFromBmpIo(try sdl3.io_stream.Stream.initFromConstMem(bmp), true);
    defer image_data_raw.deinit();
    return image_data_raw.convertFormat(sdl3.pixels.Format.packed_abgr_8_8_8_8);
}

pub fn loadShader(
    device: sdl3.gpu.Device,
    stage: sdl3.gpu.ShaderStage,
    code: []const u8,
    sampler_count: u32,
    uniform_buffer_count: u32,
    storage_buffer_count: u32,
    storage_texture_count: u32,
) !sdl3.gpu.Shader {
    return device.createShader(.{
        .code = code,
        .entry_point = "main",
        .format = .{ .spirv = true },
        .stage = stage,
        .num_samplers = sampler_count,
        .num_uniform_buffers = uniform_buffer_count,
        .num_storage_buffers = storage_buffer_count,
        .num_storage_textures = storage_texture_count,
        .props = null,
    });
}

/// Buffer for vertex input states.
pub const VertexInputStateBuffer = struct {
    /// Slot to use for the vertex buffer.
    slot: u32 = 0,
    /// CPU type to back the vertex data.
    /// This will be verified to match the byte size of the GPU backing.
    cpu_backing: type,
    /// GPU attributes that when combined recreate the vertex data.
    /// These combined will be verified to match the byte size of the CPU backing.
    vert_shader_name: []const u8,
    /// Input rate to use for the buffer.
    input_rate: sdl3.gpu.VertexInputRate = .vertex,
    /// Instance step rate.
    instance_step_rate: u32 = 0,
};

/// Ensure two used attributes do not share the same slot.
/// If two do, this can possibly cause bugs.
pub inline fn ensureNoDuplicateSlots() !void {
    comptime {
        var map = std.AutoHashMap(u32, [:0]const u8).init(std.heap.smp_allocator);
        defer map.deinit();

        // Scan vertex buffer attributes for duplicates.
        for (attributes.vertex_buffer_attributes.keys()) |key| {
            const attribs = attributes.vertex_buffer_attributes.get(key).?;
            for (attribs) |attrib| {
                if (map.get(attrib.loc)) |same_attrib_loc_name| {
                    if (!std.mem.eql(u8, attrib.name, same_attrib_loc_name)) {
                        @compileError(std.fmt.comptimePrint("Attributes {s} and {s} share the same location {d}", .{ attrib.name, same_attrib_loc_name, attrib.loc }));
                    }
                } else {
                    try map.put(attrib.loc, attrib.name);
                }
            }
        }
        map.clearRetainingCapacity();

        // Scan vertex shader out fragment shader in attributes for duplicates.
        for (attributes.vertex_out_fragment_in_attributes.keys()) |key| {
            const attribs = attributes.vertex_out_fragment_in_attributes.get(key).?;
            for (attribs) |attrib| {
                if (map.get(attrib.loc)) |same_attrib_loc_name| {
                    if (!std.mem.eql(u8, attrib.name, same_attrib_loc_name)) {
                        @compileError(std.fmt.comptimePrint("Attributes {s} and {s} share the same location {d}", .{ attrib.name, same_attrib_loc_name, attrib.loc }));
                    }
                } else {
                    try map.put(attrib.loc, attrib.name);
                }
            }
        }
    }
}

/// Ensure a vertex shader and fragment shader are compatible with each other.
///
/// ## Remarks
/// This assumes that each shader uses only attributes from the `attributes.zig` file
/// and uses a function such as `const vars = common.declareVertexShaderVars(shader_name()){};` to declare the shader variables.
/// Note that it is only important that the fragment shader's inputs are output by the vertex shader,
/// the vertex shader is allowed to output attributes to the fragment shader that go unused.
///
/// ## Function Parameters
/// * `vertex_shader_name`: The name of the vertex shader.
/// * `fragment_shader_name`: The name of the fragment shader.
pub inline fn ensureShadersCompatible(
    comptime vertex_shader_name: []const u8,
    comptime fragment_shader_name: []const u8,
) void {
    comptime {
        const vert_out_attribs = attributes.vertex_out_fragment_in_attributes.get(vertex_shader_name).?;
        const frag_in_attribs = attributes.vertex_out_fragment_in_attributes.get(fragment_shader_name).?;
        for (frag_in_attribs) |frag_in_attrib| {
            for (vert_out_attribs) |vert_out_attrib| {
                if (std.meta.eql(frag_in_attrib, vert_out_attrib))
                    break;
            } else {
                @compileError(std.fmt.comptimePrint("Fragment shader {s} expects input attribute {s}, but this was not output by vertex shader {s}", .{ fragment_shader_name, frag_in_attrib.name, vertex_shader_name }));
            }
        }
    }
}

/// Make vertex buffer descriptions given buffers information.
pub inline fn makeVertexBufferDescriptions(
    comptime buffers: []const VertexInputStateBuffer,
) [buffers.len]sdl3.gpu.VertexBufferDescription {
    comptime {
        var descriptions: [buffers.len]sdl3.gpu.VertexBufferDescription = undefined;
        for (buffers, 0..) |buffer, i| {
            descriptions[i] = makeVertexBufferDescription(buffer);
        }
        return descriptions;
    }
}

/// Make a vertex buffer description from a vertex buffer entry.
/// This will also check to make sure that the buffer types are compatible.
inline fn makeVertexBufferDescription(
    comptime buffer_entry: VertexInputStateBuffer,
) sdl3.gpu.VertexBufferDescription {
    comptime {
        const vertex_attributes = attributes.vertex_buffer_attributes.get(buffer_entry.vert_shader_name).?;
        const cpu_type_info_struct = @typeInfo(buffer_entry.cpu_backing).@"struct";
        if (vertex_attributes.len != cpu_type_info_struct.fields.len)
            @compileError(std.fmt.comptimePrint(
                "GPU \"{s}\" and CPU \"{s}\" vertex buffer structures have differing field lengths",
                .{ buffer_entry.vert_shader_name, @typeName(buffer_entry.cpu_backing) },
            ));
        for (0..vertex_attributes.len) |i| {
            if (vertex_attributes[i].cpuType() != cpu_type_info_struct.fields[i].type)
                @compileError(std.fmt.comptimePrint(
                    "GPU \"{s}\" and CPU \"{s}\" vertex buffer structures have differing field types \"{s}\" and \"{s}\"",
                    .{ buffer_entry.vert_shader_name, @typeName(buffer_entry.cpu_backing), @typeName(vertex_attributes[i].cpuType()), @typeName(cpu_type_info_struct.fields[i].type) },
                ));
        }
        return .{
            .pitch = @sizeOf(buffer_entry.cpu_backing),
            .input_rate = buffer_entry.input_rate,
            .slot = buffer_entry.slot,
            .instance_step_rate = buffer_entry.instance_step_rate,
        };
    }
}

/// Make vertex attributes given buffers information.
pub inline fn makeVertexAttributes(
    comptime buffers: []const VertexInputStateBuffer,
) [countNumAttributes(buffers)]sdl3.gpu.VertexAttribute {
    comptime {
        var ret: [countNumAttributes(buffers)]sdl3.gpu.VertexAttribute = undefined;
        var curr_ind: usize = 0;
        for (buffers) |buffer| {
            const vertex_attributes = attributes.vertex_buffer_attributes.get(buffer.vert_shader_name).?;
            for (vertex_attributes, 0..) |_, ind| {
                ret[curr_ind] = makeVertexAttribute(buffer, ind);
                curr_ind += 1;
            }
        }
        return ret;
    }
}

/// Count the number of attributes for a group of buffers.
inline fn countNumAttributes(
    comptime buffers: []const VertexInputStateBuffer,
) usize {
    comptime {
        var ret: usize = 0;
        for (buffers) |buffer| {
            const vertex_attributes = attributes.vertex_buffer_attributes.get(buffer.vert_shader_name).?;
            for (vertex_attributes) |_| {
                ret += 1;
            }
        }
        return ret;
    }
}

/// Make a vertex attribute from a buffer given the attribute/attribute index. TODO: SUPPORT ATTRIBUTES ACROSS MULTIPLE BUFFERS!!!
inline fn makeVertexAttribute(
    comptime buffer_entry: VertexInputStateBuffer,
    comptime index: usize,
) sdl3.gpu.VertexAttribute {
    comptime {
        const vertex_attributes = attributes.vertex_buffer_attributes.get(buffer_entry.vert_shader_name).?;
        const cpu_type_info_struct = @typeInfo(buffer_entry.cpu_backing).@"struct";
        if (vertex_attributes.len != cpu_type_info_struct.fields.len)
            @compileError(std.fmt.comptimePrint(
                "GPU \"{s}\" and CPU \"{s}\" vertex buffer structures have differing field lengths",
                .{ buffer_entry.vert_shader_name, @typeName(buffer_entry.cpu_backing) },
            ));
        return .{
            .location = vertex_attributes[index].loc,
            .format = getAttributeFormat(vertex_attributes[index]),
            .buffer_slot = buffer_entry.slot,
            .offset = @offsetOf(buffer_entry.cpu_backing, cpu_type_info_struct.fields[index].name),
        };
    }
}

/// Get the SDL attribute format for a GPU attribute type.
inline fn getAttributeFormat(
    comptime attribute: common.Attribute,
) sdl3.gpu.VertexElementFormat {
    comptime {
        if (attribute.cpu_type) |cpu_type| {
            if (@typeInfo(attribute.type) != .vector)
                @compileError(std.fmt.comptimePrint("GPU attribute for normalized field must be a vector for {s}", .{@typeName(attribute.type)}));
            if (@typeInfo(cpu_type) != .vector)
                @compileError(std.fmt.comptimePrint("CPU attribute for normalized field must be a vector for {s}", .{@typeName(attribute.type)}));
            const type_info = @typeInfo(attribute.type).vector;
            if (type_info.child != f32)
                @compileError(std.fmt.comptimePrint("GPU vector child type for normalized field must be f32 for {s}", .{@typeName(attribute.type)}));
            const cpu_type_info = @typeInfo(cpu_type).vector;
            if (type_info.len != cpu_type_info.len)
                @compileError(std.fmt.comptimePrint("CPU attribute has length {d} while normalized GPU attribute has length {d} for {s}", .{ cpu_type_info.len, type_info.len, @typeName(attribute.type) }));
            return switch (cpu_type) {
                @Vector(2, i8) => .i8x2_normalized,
                @Vector(4, i8) => .i8x4_normalized,
                @Vector(2, u8) => .u8x2_normalized,
                @Vector(4, u8) => .u8x4_normalized,
                @Vector(2, i16) => .i16x2_normalized,
                @Vector(4, i16) => .i16x4_normalized,
                @Vector(2, u16) => .u16x2_normalized,
                @Vector(4, u16) => .u16x4_normalized,
                else => @compileError(std.fmt.comptimePrint("Unable to get normalized attribute format for {s}", .{@typeName(attribute.type)})),
            };
        } else {
            return switch (attribute.type) {
                i32 => .i32x1,
                @Vector(1, i32) => .i32x1,
                @Vector(2, i32) => .i32x2,
                @Vector(3, i32) => .i32x3,
                @Vector(4, i32) => .i32x4,
                u32 => .u32x1,
                @Vector(1, u32) => .u32x1,
                @Vector(2, u32) => .u32x2,
                @Vector(3, u32) => .u32x3,
                @Vector(4, u32) => .u32x4,
                f32 => .f32x1,
                @Vector(1, f32) => .f32x1,
                @Vector(2, f32) => .f32x2,
                @Vector(3, f32) => .f32x3,
                @Vector(4, f32) => .f32x4,
                @Vector(2, i8) => .i8x2,
                @Vector(4, i8) => .i8x4,
                @Vector(2, u8) => .u8x2,
                @Vector(4, u8) => .u8x4,
                @Vector(2, i16) => .i16x2,
                @Vector(4, i16) => .i16x4,
                @Vector(2, u16) => .u16x2,
                @Vector(4, u16) => .u16x4,
                @Vector(2, f16) => .f16x2,
                @Vector(4, f16) => .f16x4,
                else => @compileError(std.fmt.comptimePrint("Unable to get attribute format for {s}", .{@typeName(attribute.typ)})),
            };
        }
    }
}
