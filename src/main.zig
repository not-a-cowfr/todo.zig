const std = @import("std");
const rl = @import("raylib");
const rg = @import("raygui");
const models = @import("models.zig");
const events = @import("events.zig");

const key = rl.KeyboardKey;
const color = rl.Color;

const WINDOW_HEIGHT = 720;
const WINDOW_WIDTH = 1280;

const BALLS = 100;
var speed = @as(f32, 20);

pub fn main() !void {
    rl.initWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "water sim");
    defer rl.closeWindow();

    var allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = allocator.deinit();
    const alloc = allocator.allocator();

    var balls_list = std.ArrayList(models.BallData).init(alloc);
    defer balls_list.deinit();

    var prng = std.Random.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rand = prng.random();

    for (0..BALLS) |_| {
        const data = models.BallData{
            .x = @floatFromInt(rand.intRangeAtMost(i32, 0, WINDOW_WIDTH)),
            .y = @floatFromInt(rand.intRangeAtMost(i32, 0, WINDOW_HEIGHT)),
        };
        try balls_list.append(data);
    }

    var last_tick = rl.getTime();

    var dispatcher = events.EventDispatcher.init(alloc);
    defer dispatcher.deinit();

    try dispatcher.register(on_frame, events.EventType.Frame);
    try dispatcher.register(on_tick, events.EventType.Tick);

    while (!rl.windowShouldClose()) {
        const frame_event = events.Event{ .Frame = .{ .allocator = alloc, .balls = balls_list } };
        dispatcher.post(frame_event, events.EventType.Frame);

        const current_time = rl.getTime();

        if (current_time - last_tick >= 0.05) {
            // maybe make up for extremely shit fps by checking how much more the time since last tick is
            // like if the time since last tick is 0.5s then run 10 ticks instead of just 1
            last_tick = current_time;
            const tick_event = events.Event{ .Tick = .{} };
            dispatcher.post(tick_event, events.EventType.Tick);
        }
    }
}

fn on_frame(event: events.Event) void {
    const allocator = event.Frame.allocator;
    const balls = event.Frame.balls;

    rl.beginDrawing();
    defer rl.endDrawing();

    rl.clearBackground(color.white);

    for (balls.items) |*ball_data| {
        rl.drawCircle(@intFromFloat(ball_data.x), @intFromFloat(ball_data.y), 10, color.blue);

        const new_height = ball_data.y + (speed * rl.getFrameTime());
        if (new_height < WINDOW_HEIGHT) {
            ball_data.y = new_height;
        } else {
            ball_data.y = WINDOW_HEIGHT;
        }
    }

    const fps_text = std.fmt.allocPrintZ(allocator, "fps: {}", .{rl.getFPS()}) catch "Error";
    defer allocator.free(fps_text);
    rl.drawText(fps_text, 2, 0, 30, color.black);

    const speed_text = std.fmt.allocPrintZ(allocator, "speed: {}", .{@as(i32, @intFromFloat(speed))}) catch "Error";
    defer allocator.free(speed_text);
    rl.drawText(speed_text, 2, 30, 30, color.black);
}

fn on_tick(event: events.Event) void {
    _ = event;

    if (rl.isKeyDown(key.up)) speed += 5;
    if (rl.isKeyDown(key.down)) speed -= 5;
}
