const std = @import("std");

const rl = @import("raylib");
const rg = @import("raygui");

const handlers = @import("dispatch_gen.zig");
const models = @import("models.zig");
const events = @import("events.zig");
const physics = @import("physics.zig");

const color = rl.Color;
const gl = rl.gl;
const key = rl.KeyboardKey;

pub const WINDOW_HEIGHT = 720;
pub const WINDOW_WIDTH = 1280;
pub const TPS = 50;

pub const BALLS_COUNT = 10000;
pub const BALLS_ARRAY_SIZE = @sizeOf(models.BallData) * BALLS_COUNT;

pub const GL_ARRAY_BUFFER = 0x8892;

pub fn main() !void {
    // raylib init
    rl.setConfigFlags(
        rl.ConfigFlags{
            .vsync_hint = true,
        },
    );
    rl.initWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "water sim");
    defer rl.closeWindow();

    const camera = rl.Camera2D{
        .target = .{ .x = 0, .y = 0 },
        .offset = .{ .x = 0, .y = 0 },
        .rotation = 0.0,
        .zoom = 1.0,
    };

    // alloc init
    var allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = allocator.deinit();
    const alloc = allocator.allocator();

    // events init
    var dispatcher = try handlers.init(alloc);
    defer dispatcher.deinit();

    // rng init
    var prng = std.Random.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rand = prng.random();

    // balls init
    var balls_list = std.ArrayList(models.BallData).init(alloc);
    defer balls_list.deinit();

    for (0..BALLS_COUNT) |_| {
        const data = models.BallData{
            .pos = .{
                .y = @floatFromInt(rand.intRangeAtMost(i32, 0, WINDOW_HEIGHT)),
                .x = @floatFromInt(rand.intRangeAtMost(i32, 0, WINDOW_WIDTH)),
            },
            .velocity = .{
                .x = 0,
                .y = 0,
            },
            .color = color.sky_blue,
        };
        try balls_list.append(data);
    }

    _ = try std.Thread.spawn(.{}, tick_loop, .{ alloc, balls_list, &dispatcher });

    // instanced rendering stuff
    const target = try rl.loadRenderTexture(WINDOW_WIDTH, WINDOW_HEIGHT);
    defer rl.unloadRenderTexture(target);

    rl.setTextureFilter(target.texture, rl.TextureFilter.bilinear);

    const instance_shader = try rl.loadShader("src/shaders/instancing.vs", null);
    defer rl.unloadShader(instance_shader);

    var batch = gl.rlLoadRenderBatch(1, 36);

    batch.instances = BALLS_COUNT;

    var use_instanced = true;

    // main loop
    while (!rl.windowShouldClose()) {
        if (rl.isKeyPressed(key.m)) use_instanced = !use_instanced;

        const frame_event = events.Event{
            .Frame = .{
                .allocator = alloc,

                .rendering = .{
                    .balls = balls_list,
                    .batch = batch,
                    .shader = instance_shader,
                    .use_instanced = use_instanced,
                    .camera = camera,
                },
            },
        };
        dispatcher.post(frame_event, events.EventType.Frame);
    }
}

fn tick_loop(allocator: std.mem.Allocator, balls_list: std.ArrayList(models.BallData), dispatcher: *events.EventDispatcher) void {
    const interval: f64 = std.time.ns_per_s / TPS;
    var count: u128 = 0;

    while (true) {
        count += 1;
        const tick_event = events.Event{
            .Tick = .{
                .allocator = allocator,
                .balls = balls_list,
                .count = count,
            },
        };
        dispatcher.post(tick_event, events.EventType.Tick);

        std.time.sleep(interval);
    }
}

// @EventHandler(Frame)
pub fn on_frame(e: events.Event) void {
    const event = e.Frame;
    const allocator = event.allocator;
    const r = event.rendering;

    rl.beginDrawing();
    defer rl.endDrawing();

    rl.clearBackground(color.white);

    rl.beginMode2D(r.camera);

    if (r.use_instanced) {
        rl.beginShaderMode(r.shader);
        gl.rlSetRenderBatchActive(@constCast(&r.batch));

        // rl.drawCircle(, , 10, color.blue);
        gl.rlDrawRenderBatchActive();

        gl.rlSetRenderBatchActive(null);
        rl.endShaderMode();
    } else {
        for (r.balls.items) |*ball_data| {
            rl.drawCircle(@intFromFloat(ball_data.pos.x), @intFromFloat(ball_data.pos.y), 10, color.blue);
        }
    }

    const fps_text = std.fmt.allocPrintZ(allocator, "fps: {}", .{rl.getFPS()}) catch "Error";
    defer allocator.free(fps_text);
    rl.drawText(fps_text, 2, 0, 30, color.black);

    const speed_text = std.fmt.allocPrintZ(allocator, "gravity: {}", .{@as(i32, @intFromFloat(physics.GRAVITY))}) catch "Error";
    defer allocator.free(speed_text);
    rl.drawText(speed_text, 2, 30, 30, color.black);

    const rendering_text = std.fmt.allocPrintZ(allocator, "rendering: {s}", .{if (r.use_instanced) "instanced" else "regular"}) catch "Error";
    defer allocator.free(rendering_text);
    rl.drawText(rendering_text, 2, 60, 30, color.black);
}
