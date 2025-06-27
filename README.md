# SDL GPU Examples
Examples for SDL3's GPU subsystem utilizing zig shaders.
Note that this requires the latest zig master, as SPIR-V's image type is not supported by the latest zig release's assembler at the moment.
This is an alternative of [the official examples](https://github.com/Gota7/zig-sdl3/tree/master/gpu_examples) for this reason.
Once everything in these examples are supported by an official zig release, this will replace the official examples.

## Motivation
GPU programming is tricky.
One must ensure buffer layouts are correct both on the CPU and GPU side, the vertex and fragment shaders are compatible, you declared all the pipeline information on the CPU side correctly, etc.

By having shaders be in zig and utilizing compile time reflection, pipe-line creation code can be partially automated.
This allows for the ability to catch errors at compile-time rather than running into the sad black screen at run-time.
This also allows for less overhead you need to write in general!
Declare your shader info once in the `src/shaders/attributes.zig` file and everything else will work like magic!

## Running
Simply run `zig build run`.
