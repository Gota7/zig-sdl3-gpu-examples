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

    // Just forward out the color.
    vars.vert_out_color.* = vars.vert_in_color.*;

    // Use the instance index to offset the vertex.
    var pos = vars.vert_in_position.* * @as(@Vector(3, f32), @splat(0.25)) - @Vector(3, f32){ 0.75, 0.75, 0 };
    pos[0] += @as(f32, @floatFromInt(std.gpu.instance_index % 4)) * 0.5;
    pos[1] += @as(f32, @floatFromInt(std.gpu.instance_index / 4)) * 0.5;
    std.gpu.position_out.* = attributes.vert_out_position_type{ pos[0], pos[1], pos[2], 1 };
}
