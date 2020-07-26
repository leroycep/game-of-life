const std = @import("std");
const platform = @import("platform.zig");
const constants = @import("constants.zig");
const app = @import("app.zig");
const Timer = std.time.Timer;

pub fn main() !void {
    const alloc = std.heap.c_allocator;

    var context = try platform.init(alloc, constants.APP_NAME, 640, 480);
    // TODO: call this from Context
    defer context.deinit();

    app.onInit(&context);

    // Timestep based on the Gaffer on Games post, "Fix Your Timestep"
    //    https://www.gafferongames.com/post/fix_your_timestep/
    const MAX_DELTA = constants.MAX_DELTA_SECONDS;
    const TICK_DELTA = constants.TICK_DELTA_SECONDS;
    var timer = try Timer.start();
    var tickTime: f64 = 0.0;
    var accumulator: f64 = 0.0;

    while (platform.shouldQuit != platform.QUIT) {
        while (platform.pollEvent()) |event| {
            app.onEvent(&context, event);
        }

        var delta = @intToFloat(f64, timer.lap()) / std.time.ns_per_s; // Delta in seconds
        if (delta > MAX_DELTA) {
            delta = MAX_DELTA; // Try to avoid spiral of death when lag hits
        }

        accumulator += delta;

        while (accumulator >= TICK_DELTA) {
            app.update(&context, tickTime, TICK_DELTA);
            accumulator -= TICK_DELTA;
            tickTime += TICK_DELTA;
        }

        // Where the render is between two timesteps.
        // If we are halfway between frames (based on what's in the accumulator)
        // then alpha will be equal to 0.5
        const alpha = accumulator / TICK_DELTA;

        context.renderer.begin();

        app.render(&context, alpha);

        //context.renderer.flush();
        context.flush();

        std.time.sleep(10_000);
    }
}
