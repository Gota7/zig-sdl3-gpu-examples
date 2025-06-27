const attributes = @import("attributes.zig");
const std = @import("std");

/// Declare variables for a vertex shader.
///
/// ## Function Parameters
/// * `src`: The shader name to look up in the attributes map.
///
/// ## Remarks
/// The `vert_in_index`, `vert_in_instance_index`, and `vert_out_position` pointers are always available.
///
/// ## Return Value
/// Returns a type that can be initiated at compile time to access vars for the variable shader.
/// For example, if you have `vert_in_position` as an attribute for `my_shader.vert.zig`, then declare `const vars = common.declareVertexShaderVars("my_shader.vert.zig"){}`.
/// Then, you can access `vars.vert_in_position` as the vertex position.
pub inline fn declareVertexShaderVars(
    comptime src: []const u8,
) type {
    comptime {

        // Get vertex buffer attributes for the shader.
        var curr_field: usize = 0;
        const in_attribs = attributes.vertex_buffer_attributes.get(src[0 .. src.len - 4]).?; // Remove zig extension.
        const out_attribs = attributes.vertex_out_fragment_in_attributes.get(src[0 .. src.len - 4]).?; // Remove zig extension.
        var fields: [in_attribs.len + out_attribs.len]std.builtin.Type.StructField = undefined;

        // Get extern pointers for each buffer attribute (so we can use as location later).
        var in_ptrs: [in_attribs.len]*addrspace(.input) const anyopaque = undefined;
        for (in_attribs, 0..) |attrib, i| {
            in_ptrs[i] = @extern(*addrspace(.input) const attrib.type, .{ .name = attrib.name ++ ".in" });
        }
        var out_ptrs: [out_attribs.len]*addrspace(.output) anyopaque = undefined;
        for (out_attribs, 0..) |attrib, i| {
            out_ptrs[i] = @extern(*addrspace(.output) attrib.type, .{ .name = attrib.name ++ ".out" });
        }

        // Create fields in our return struct to use as our vertex attributes.
        // Note we set the default value of each attribute to the corresponding extern pointer so we can access the buffer attribute data.
        for (in_attribs, 0..) |attrib, i| {
            if (attrib.stage != .vert_input)
                @compileLog(std.fmt.comptimePrint("Attribute stage for {s} for shader {s} is not a vertex input when needed to be one", .{ attrib.name, src }));
            fields[curr_field] = .{
                .name = "vert_in_" ++ attrib.name,
                .type = *addrspace(.input) const attrib.type,
                .default_value_ptr = @ptrCast(&in_ptrs[i]),
                .is_comptime = false,
                .alignment = @alignOf(*addrspace(.input) const attrib.type),
            };
            curr_field += 1;
        }
        for (out_attribs, 0..) |attrib, i| {
            if (attrib.stage != .vert_output_frag_input)
                @compileLog(std.fmt.comptimePrint("Attribute stage for {s} for shader {s} is not a vertex output/fragment input when needed to be one", .{ attrib.name, src }));
            fields[curr_field] = .{
                .name = "vert_out_" ++ attrib.name,
                .type = *addrspace(.output) attrib.type,
                .default_value_ptr = @ptrCast(&out_ptrs[i]),
                .is_comptime = false,
                .alignment = @alignOf(*addrspace(.output) attrib.type),
            };
            curr_field += 1;
        }

        return @Type(.{
            .@"struct" = .{
                .layout = .auto,
                .fields = &fields,
                .decls = &.{},
                .is_tuple = false,
            },
        });
    }
}

/// Bind vertex shader variables.
///
/// ## Function Parameters
/// * `vars`: The vertex shader variables.
/// * `src`: The name of the shader file.
pub inline fn bindVertexShaderVars(
    comptime vars: anytype,
    comptime src: []const u8,
) void {

    // Get vertex buffer attributes for the shader.
    const in_attribs = runtimeAttributesFromCompileTimeAttributes(attributes.vertex_buffer_attributes.get(src[0 .. src.len - 4]).?); // Remove zig extension.
    const out_attribs = runtimeAttributesFromCompileTimeAttributes(attributes.vertex_out_fragment_in_attributes.get(src[0 .. src.len - 4]).?); // Remove zig extension.

    // Declare bindings for each field.
    inline for (in_attribs) |attrib| {
        std.gpu.location(@field(vars, "vert_in_" ++ attrib.name), attrib.loc);
    }
    inline for (out_attribs) |attrib| {
        std.gpu.location(@field(vars, "vert_out_" ++ attrib.name), attrib.loc);
    }
}

/// Declare variables for a fragment shader.
///
/// ## Function Parameters
/// * `src`: The shader name to look up in the attributes map.
///
/// ## Remarks
/// The `frag_out_color` pointer is always available.
///
/// ## Return Value
/// Returns a type that can be initiated at compile time to access vars for the variable shader.
/// For example, if you have `frag_in_color` as an attribute for `my_shader.frag.zig`, then declare `const vars = common.declareVertexShaderVars("my_shader.frag.zig"){}`.
/// Then, you can access `vars.frag_in_color` as the input color.
pub inline fn declareFragmentShaderVars(
    comptime src: []const u8,
) type {
    comptime {

        // Get vertex buffer attributes for the shader.
        var curr_field: usize = 0;
        const in_attribs = attributes.vertex_out_fragment_in_attributes.get(src[0 .. src.len - 4]).?; // Remove zig extension.
        var fields: [in_attribs.len + 1]std.builtin.Type.StructField = undefined;

        // Get extern pointers for each buffer attribute (so we can use as location later).
        var in_ptrs: [in_attribs.len]*addrspace(.input) const anyopaque = undefined;
        for (in_attribs, 0..) |attrib, i| {
            in_ptrs[i] = @extern(*addrspace(.input) const attrib.type, .{ .name = attrib.name ++ ".in" });
        }

        // Create fields in our return struct to use as our vertex attributes.
        // Note we set the default value of each attribute to the corresponding extern pointer so we can access the buffer attribute data.
        for (in_attribs, 0..) |attrib, i| {
            if (attrib.stage != .vert_output_frag_input)
                @compileLog(std.fmt.comptimePrint("Attribute stage for {s} for shader {s} is not a fragment input when needed to be one", .{ attrib.name, src }));
            fields[curr_field] = .{
                .name = "frag_in_" ++ attrib.name,
                .type = *addrspace(.input) const attrib.type,
                .default_value_ptr = @ptrCast(&in_ptrs[i]),
                .is_comptime = false,
                .alignment = @alignOf(*addrspace(.input) const attrib.type),
            };
            curr_field += 1;
        }

        // Fragment out color is always available and hardcoded in.
        const frag_out_color = @extern(*addrspace(.output) attributes.frag_out_color.type, .{ .name = "frag_out_color" });
        fields[curr_field] = .{
            .name = "frag_out_color",
            .type = *addrspace(.output) attributes.frag_out_color.type,
            .default_value_ptr = @ptrCast(&frag_out_color),
            .is_comptime = false,
            .alignment = @alignOf(*addrspace(.output) attributes.frag_out_color.type),
        };

        return @Type(.{
            .@"struct" = .{
                .layout = .auto,
                .fields = &fields,
                .decls = &.{},
                .is_tuple = false,
            },
        });
    }
}

/// Bind fragment shader variables.
///
/// ## Function Parameters
/// * `vars`: The fragment shader variables.
/// * `src`: The name of the shader file.
pub inline fn bindFragmentShaderVars(
    comptime vars: anytype,
    comptime src: []const u8,
    comptime main: anytype,
) void {
    std.gpu.executionMode(main, .origin_upper_left);

    // Get vertex buffer attributes for the shader.
    const in_attribs = runtimeAttributesFromCompileTimeAttributes(attributes.vertex_out_fragment_in_attributes.get(src[0 .. src.len - 4]).?); // Remove zig extension.

    // Declare bindings for each field.
    inline for (in_attribs) |attrib| {
        std.gpu.location(@field(vars, "frag_in_" ++ attrib.name), attrib.loc);
    }

    // Fragment out color always exists.
    std.gpu.location(vars.frag_out_color, attributes.frag_out_color.loc);
}

/// Stage of data for the attribute parameter.
pub const AttributeStage = enum {
    /// Input for the vertex stage. Provided by a vertex buffer.
    vert_input,
    /// Output of the vertex stage but an input for the fragment stage.
    vert_output_frag_input,
    /// Output of the fragment stage.
    frag_output,
};

/// GPU attribute structure.
pub const Attribute = struct {
    /// Name of the attribute.
    name: [:0]const u8,
    /// Attribute location.
    /// This has to be unique among attributes for each stage type, but does not have to be unique across different stage types.
    loc: u32,
    /// Data type for the GPU side (and CPU side if the `cpu_type` is not set).
    type: type,
    /// If not null, use a different type on the CPU side.
    /// These will be normalized to floats for the GPU side and so `type` must be a vector of floats if this is used!
    /// This is only useful for CPU <-> Vertex Shader bindings.
    cpu_type: ?type = null,
    /// Stage the uniform exists in.
    stage: AttributeStage,

    /// Get the type for the CPU side.
    pub inline fn cpuType(comptime self: Attribute) type {
        if (self.cpu_type) |val| {
            return val;
        }
        return self.type;
    }
};

/// GPU attribute but usable at runtime.
const AttributeRuntime = struct {
    /// Name of the attribute.
    name: [:0]const u8,
    /// Attribute location.
    /// This has to be unique among attributes for each stage type, but does not have to be unique across different stage types.
    loc: u32,
    stage: AttributeStage,

    /// Create a runtime attribute from a compile time attribute.
    pub fn fromComptime(
        attrib: Attribute,
    ) AttributeRuntime {
        return .{
            .name = attrib.name,
            .loc = attrib.loc,
            .stage = attrib.stage,
        };
    }
};

/// Get runtime-comptible attributes from compile time attributes.
inline fn runtimeAttributesFromCompileTimeAttributes(
    comptime attribs: []const Attribute,
) [attribs.len]AttributeRuntime {
    comptime {
        var ret: [attribs.len]AttributeRuntime = undefined;
        for (attribs, 0..) |attrib, i| {
            ret[i] = AttributeRuntime.fromComptime(attrib);
        }
        return ret;
    }
}

/// Sampler 2d type.
const Sampler2d = *const anyopaque;

/// Create a sampler 2d uniform.
///
/// ## Function Parameters
/// * `set`: The descriptor set.
/// * `bind`: The binding slot.
///
/// ## Return Value
/// Returns a sampler that can be sampled with `textureSampler2d()`.
pub fn sampler2d(
    comptime set: u32,
    comptime bind: u32,
) Sampler2d {
    const ret = asm volatile (
        \\%float       = OpTypeFloat 32
        \\%img         = OpTypeImage %float 2D 0 0 0 1 Unknown
        \\%sampler     = OpTypeSampledImage %img
        \\%sampler_ptr = OpTypePointer UniformConstant %sampler
        \\%tex         = OpVariable %sampler_ptr UniformConstant
        \\               OpDecorate %tex DescriptorSet $set
        \\               OpDecorate %tex Binding $bind
        : [tex] "" (-> Sampler2d),
        : [set] "c" (set),
          [bind] "c" (bind),
    );
    return ret;
}

/// Use a sampler2d to sample texture data.
///
/// ## Function Parameters
/// * `sampler`: The sampler to sample the texture data from.
/// * `uv`: The coordinates to sample.
///
/// ## Return Value
/// Returns the RGBA normalized color data of the sample.
pub inline fn textureSampler2d(
    sampler: Sampler2d,
    uv: @Vector(2, f32),
) @Vector(4, f32) {
    const ret = asm volatile (
        \\%float          = OpTypeFloat 32
        \\%img            = OpTypeImage %float 2D 0 0 0 1 Unknown
        \\%sampler_type   = OpTypeSampledImage %img
        \\%v4float        = OpTypeVector %float 4
        \\%loaded_sampler = OpLoad %sampler_type %sampler
        \\%ret            = OpImageSampleImplicitLod %v4float %loaded_sampler %uv
        : [ret] "" (-> @Vector(4, f32)),
        : [sampler] "" (sampler),
          [uv] "" (uv),
    );
    return ret;
}
