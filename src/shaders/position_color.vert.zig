const attributes = @import("attributes.zig");
const common = @import("common.zig");
const std = @import("std");

/// Get the name of this shader file.
fn shader_name() []const u8 {
    return @src().file;
}

// Vertex shader variables.
const vars = common.declareVertexShaderVars(shader_name()){};

export fn main() callconv(.spirv_vertex) void {

    // Bind vertex shader variables to the current shader.
    common.bindVertexShaderVars(vars, shader_name());

    // Just forward the position and color.
    std.gpu.position_out.* = attributes.vert_out_position_type{ vars.vert_in_position.*[0], vars.vert_in_position.*[1], vars.vert_in_position.*[2], 1 };
    vars.vert_out_color.* = vars.vert_in_color.*;
}
