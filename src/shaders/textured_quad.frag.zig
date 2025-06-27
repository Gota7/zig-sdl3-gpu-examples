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

    // const sampler2d = common.sampler2d(2, 0);

    // // Simple out = in.
    // vars.frag_out_color.* = common.textureSampler2d(sampler2d, vars.frag_in_uv.*);

    const color: @Vector(4, f32) = asm volatile (
        \\%float          = OpTypeFloat 32
        \\%v4float        = OpTypeVector %float 4
        \\%img_type       = OpTypeImage %float 2D 0 0 0 1 Unknown
        \\%sampler_type   = OpTypeSampledImage %img_type
        \\%sampler_ptr    = OpTypePointer UniformConstant %sampler_type
        \\%tex            = OpVariable %sampler_ptr UniformConstant
        \\                  OpDecorate %tex DescriptorSet 2
        \\                  OpDecorate %tex Binding 0
        \\%loaded_sampler = OpLoad %sampler_type %tex
        \\%ret            = OpImageSampleImplicitLod %v4float %loaded_sampler %uv
        : [ret] "" (-> @Vector(4, f32)),
        : [uv] "" (vars.frag_in_uv.*),
    );
    vars.frag_out_color.* = color;
}
