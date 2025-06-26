const attributes = @import("attributes.zig");
const common = @import("common.zig");
const std = @import("std");

/// Get the name of this shader file.
fn shader_name() []const u8 {
    return @src().file;
}

/// Fragment shader variables.
const vars = common.declareFragmentShaderVars(shader_name()){};

export fn main() callconv(.spirv_fragment) void {

    // Bind fragment shader variables to the current shader.
    common.bindFragmentShaderVars(vars, shader_name(), main);

    // Simple out = in.
    vars.frag_out_color.* = vars.frag_in_color.*;
}
