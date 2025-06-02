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
var BALL_MASS = @as(f32, 10);

var GRAVITY = @as(f32, 10);
// 100 = no energy lost, 0 = all energy lost
const MASS_DAMPING = 100.0;

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
            .pos = .{
                .y = @floatFromInt(rand.intRangeAtMost(i32, 0, WINDOW_HEIGHT)),
                .x = @floatFromInt(rand.intRangeAtMost(i32, 0, WINDOW_WIDTH)),
            },
            .velocity = .{
                .x = 0,
                .y = 0,
            },
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
        rl.drawCircle(@intFromFloat(ball_data.pos.x), @intFromFloat(ball_data.pos.y), 10, color.blue);
    }

    const fps_text = std.fmt.allocPrintZ(allocator, "fps: {}", .{rl.getFPS()}) catch "Error";
    defer allocator.free(fps_text);
    rl.drawText(fps_text, 2, 0, 30, color.black);

    const speed_text = std.fmt.allocPrintZ(allocator, "gravity: {}", .{@as(i32, @intFromFloat(GRAVITY))}) catch "Error";
    defer allocator.free(speed_text);
    rl.drawText(speed_text, 2, 30, 30, color.black);
}

// @EventHandler(Tick)
pub fn on_tick(event: events.Event) void {
    if (rl.isKeyDown(key.up)) GRAVITY -= 1;
    if (rl.isKeyDown(key.down)) GRAVITY += 1;

    const MASS_FACTOR = 1.0 - (BALL_MASS / MASS_DAMPING);

    for (event.components.balls.items) |*ball_data| {
        calcAcceleration(&ball_data.velocity);

        ball_data.pos.x -= (ball_data.velocity.x / TPS);
        ball_data.pos.y -= (ball_data.velocity.y / TPS);

        if (ball_data.pos.x <= 0 or ball_data.pos.x >= WINDOW_WIDTH) {
            ball_data.velocity.x *= -1 * MASS_FACTOR;
            ball_data.pos.x = @min(@max(ball_data.pos.x, 0), WINDOW_WIDTH);
        }
        if (ball_data.pos.y <= 0 or ball_data.pos.y >= WINDOW_HEIGHT) {
            ball_data.velocity.y *= -1 * MASS_FACTOR;
            ball_data.pos.y = @min(@max(ball_data.pos.y, 0), WINDOW_HEIGHT);
        }
    }
}

fn calcAcceleration(velocity: *models.Vec2) void {
    velocity.y -= GRAVITY;
}
