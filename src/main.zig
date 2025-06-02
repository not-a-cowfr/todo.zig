const std = @import("std");
const rl = @import("raylib");
const rg = @import("raygui");
const handlers = @import("dispatch_gen.zig");
const models = @import("models.zig");
const events = @import("events.zig");

const key = rl.KeyboardKey;
const color = rl.Color;

const WINDOW_HEIGHT = 720;
const WINDOW_WIDTH = 1280;
const TPS = 50;

const BALLS_COUNT = 100;
var SPEED = @as(f32, 10);

pub fn main() !void {
    // raylib init
    rl.initWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "water sim");
    defer rl.closeWindow();

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
            .x = @floatFromInt(rand.intRangeAtMost(i32, 0, WINDOW_WIDTH)),
            .y = @floatFromInt(rand.intRangeAtMost(i32, 0, WINDOW_HEIGHT)),
        };
        try balls_list.append(data);
    }

    _ = try std.Thread.spawn(.{}, tick_loop, .{ alloc, balls_list, &dispatcher });

    // main loop
    while (!rl.windowShouldClose()) {
        const frame_event = events.Event{ .allocator = alloc, .components = .{ .balls = balls_list } };
        dispatcher.post(frame_event, events.EventType.Frame);
    }
}

fn tick_loop(allocator: std.mem.Allocator, balls_list: std.ArrayList(models.BallData), dispatcher: *events.EventDispatcher) void {
    const interval: f64 = (1 * std.time.ns_per_s) / TPS;

    while (true) {
        const tick_event = events.Event{ .allocator = allocator, .components = .{ .balls = balls_list } };
        dispatcher.post(tick_event, events.EventType.Tick);

        std.time.sleep(interval);
    }
}

// @EventHandler(Frame)
pub fn on_frame(event: events.Event) void {
    const allocator = event.allocator;

    rl.beginDrawing();
    defer rl.endDrawing();

    rl.clearBackground(color.white);

    for (event.components.balls.items) |*ball_data| {
        rl.drawCircle(@intFromFloat(ball_data.x), @intFromFloat(ball_data.y), 10, color.blue);
    }

    const fps_text = std.fmt.allocPrintZ(allocator, "fps: {}", .{rl.getFPS()}) catch "Error";
    defer allocator.free(fps_text);
    rl.drawText(fps_text, 2, 0, 30, color.black);

    const speed_text = std.fmt.allocPrintZ(allocator, "speed: {}", .{@as(i32, @intFromFloat(SPEED))}) catch "Error";
    defer allocator.free(speed_text);
    rl.drawText(speed_text, 2, 30, 30, color.black);
}

// @EventHandler(Tick)
pub fn on_tick(event: events.Event) void {
    if (rl.isKeyDown(key.up)) SPEED += 1;
    if (rl.isKeyDown(key.down)) SPEED -= 1;

    for (event.components.balls.items) |*ball_data| {
        ball_data.y += SPEED;
        ball_data.y = @min(@max(ball_data.y, 0), WINDOW_HEIGHT);
        ball_data.x = @min(@max(ball_data.x, 0), WINDOW_WIDTH);
    }
}
