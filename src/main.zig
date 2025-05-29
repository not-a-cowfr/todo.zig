const std = @import("std");
const rl = @import("raylib");
const rg = @import("raygui");
const models = @import("models.zig");

const key = rl.KeyboardKey;
const color = rl.Color;

const WINDOW_HEIGHT = 720;
const WINDOW_WIDTH = 1280;

const BALLS = 100;
var speed = @as(f32, 20);

pub fn main() !void {
    rl.initWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "water sim");
    defer rl.closeWindow();

    // rl.setTargetFPS(60);

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

        // try alloc.dupe(
        //     BallData,
        //     data,
        // );
        try balls_list.append(data);
    }

    var last_tick = rl.getTime();

    while (!rl.windowShouldClose()) {
        try on_frame(alloc, balls_list);

        const current_time = rl.getTime();

        if (current_time - last_tick >= 0.05) {
            // maybe make up for extremely shit fps by checking how much more the time since last tick is
            // like if the time since last tick is 0.5s then run 10 ticks instead of just 1
            last_tick = current_time;
            try on_tick();
        }
    }
}

fn on_frame(alloc: std.mem.Allocator, balls_list: std.ArrayList(models.BallData)) !void {
    rl.beginDrawing();
    defer rl.endDrawing();

    rl.clearBackground(color.white);

    for (balls_list.items) |*ball_data| {
        rl.drawCircle(@intFromFloat(ball_data.x), @intFromFloat(ball_data.y), 10, color.blue);

        const new_height = ball_data.y + (speed * rl.getFrameTime());
        if (new_height < WINDOW_HEIGHT) {
            ball_data.y = new_height;
        } else {
            ball_data.y = WINDOW_HEIGHT;
        }
    }

    const fps_text = try std.fmt.allocPrintZ(alloc, "fps: {}", .{rl.getFPS()});
    defer alloc.free(fps_text);
    rl.drawText(fps_text, 2, 0, 30, color.black);

    const speed_text = try std.fmt.allocPrintZ(alloc, "speed: {}", .{@as(i32, @intFromFloat(speed))});
    defer alloc.free(speed_text);
    rl.drawText(speed_text, 2, 30, 30, color.black);
}

fn on_tick() !void {
    if (rl.isKeyDown(key.up)) speed += 5;
    if (rl.isKeyDown(key.down)) speed -= 5;
}
