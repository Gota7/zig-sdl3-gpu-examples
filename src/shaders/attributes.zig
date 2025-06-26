const Attribute = @import("common.zig").Attribute;
const std = @import("std");

// The GPU has multiple "locations" that can be used for inputs and outputs for either the vertex or fragment stage.
// For example, we may have a vertex shader that takes in a position and color and will output a color to later be consumed by the fragment shader.
// Note that the position element for a vertex shader must be output as it is hardcoded to its pipeline.
// In the example above, we would use the `vert_in_position`, `vert_in_color`, and `vert_out_frag_in_color` attributes.
// We use these in `position_color.vert.zig`.
// Unfortunately, using the attributes in the shader code is a bit messy and hard to communicate.
// Below is a listing of the different possible attributes being used throughout the shaders.
// Prefixes are automatically added to the name. Ex: `vert_out_frag_in_color` has a name of `color` and so the attribute variable will be named either `vert_out_color` or `frag_in_color`.
// The prefix used depends on if the attribute is used in the vertex or fragment shader.

/// Input type for vertex index.
/// This is a hardcoded input for the vertex stage.
pub const vert_in_index_type = u32;

/// Input type for vertex instance index.
/// This is a hardcoded input for the vertex stage.
pub const vert_in_instance_index_type = u32;

/// Attribute to use for input vertex position.
pub const vert_in_position = Attribute{
    .name = "position",
    .loc = 0,
    .type = @Vector(3, f32),
    .stage = .vert_input,
};

/// Attribute to use for input vertex color.
pub const vert_in_color = Attribute{
    .name = "color",
    .loc = 1,
    .type = @Vector(4, f32),
    .cpu_type = @Vector(4, u8),
    .stage = .vert_input,
};

/// Attribute to use for input vertex texture coordinates.
pub const vert_in_uv = Attribute{
    .name = "uv",
    .loc = 2,
    .type = @Vector(2, f32),
    .stage = .vert_input,
};

/// Output type for vertex position.
/// This is a hardcoded output for the vertex stage.
pub const vert_out_position_type = @Vector(4, f32);

/// Attribute to use for vertex color outputs.
pub const vert_out_frag_in_color = Attribute{
    .name = "color",
    .loc = 0,
    .type = @Vector(4, f32),
    .stage = .vert_output_frag_input,
};

/// Attribute to use for vertex texture coordinates.
pub const vert_out_frag_in_uv = Attribute{
    .name = "uv",
    .loc = 1,
    .type = @Vector(2, f32),
    .stage = .vert_output_frag_input,
};

// Note that vertex output locations and fragment output locations are allowed to overlap because they are different address spaces.
// Any vertex output location works as a fragment input location.

/// The fragment output color location should just be 0.
/// I don't know why, it's just expected to be at 0.
/// This is hardcoded as an output for fragment shaders.
pub const frag_out_color = Attribute{
    .name = "color",
    .loc = 0,
    .type = @Vector(4, f32),
    .stage = .frag_output,
};

/// Defines vertex buffer attributes for all the vertex shaders.
/// This must be kept up to date with each vertex shader, to ensure CPU <-> GPU Vertex Shader attribute mappings function properly.
pub const vertex_buffer_attributes = std.StaticStringMap([]const Attribute).initComptime(&.{
    .{
        "position_color.vert", &.{
            vert_in_position,
            vert_in_color,
        },
    },
    .{
        "position_color_instanced.vert", &.{
            vert_in_position,
            vert_in_color,
        },
    },
    .{
        "textured_quad.vert", &.{
            vert_in_position,
            vert_in_uv,
        },
    },
    .{ "raw_triangle.vert", &[_]Attribute{} },
});

/// Defines attributes for vertex shader outputs and fragment shader inputs.
/// This must be kept up to date with each vertex and fragment shader, to ensure Vertex Shader <-> Fragment Shader attributes function properly.
pub const vertex_out_fragment_in_attributes = std.StaticStringMap([]const Attribute).initComptime(&.{
    .{
        "position_color.vert", &.{
            vert_out_frag_in_color,
        },
    },
    .{
        "position_color_instanced.vert", &.{
            vert_out_frag_in_color,
        },
    },
    .{
        "raw_triangle.vert", &.{
            vert_out_frag_in_color,
        },
    },
    .{
        "textured_quad.vert", &.{
            vert_out_frag_in_uv,
        },
    },
    .{
        "solid_color.frag", &.{
            vert_out_frag_in_color,
        },
    },
    .{
        "textured_quad.frag", &.{
            vert_out_frag_in_uv,
        },
    },
});
