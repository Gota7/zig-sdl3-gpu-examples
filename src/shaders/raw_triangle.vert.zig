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

    // Since we are drawing 1 primitive triangle, the indices 0, 1, and 2 are the only vetices expected.
    switch (std.gpu.vertex_index) {
        0 => {
            std.gpu.position_out.* = .{ -1, -1, 0, 1 };
            vars.vert_out_color.* = .{ 1, 0, 0, 1 };
        },
        1 => {
            std.gpu.position_out.* = .{ 1, -1, 0, 1 };
            vars.vert_out_color.* = .{ 0, 1, 0, 1 };
        },
        else => {
            std.gpu.position_out.* = .{ 0, 1, 0, 1 };
            vars.vert_out_color.* = .{ 0, 0, 1, 1 };
        },
    }
}
