const rl = @import("raylib");
const events = @import("events.zig");
const main = @import("main.zig");
const models = @import("models.zig");

const key = rl.KeyboardKey;

pub var BALL_MASS = @as(f32, 10);

pub var GRAVITY = @as(f32, 10);
// 100 = no energy lost, 0 = all energy lost
pub const MASS_DAMPING = 100.0;

// @EventHandler(Tick)
pub fn on_tick(event: events.Event) void {
    if (rl.isKeyDown(key.up)) GRAVITY -= 1;
    if (rl.isKeyDown(key.down)) GRAVITY += 1;

    const MASS_FACTOR = 1.0 - (BALL_MASS / MASS_DAMPING);

    for (event.components.balls.items) |*ball_data| {
        calcAcceleration(&ball_data.velocity);

        ball_data.pos.x -= (ball_data.velocity.x / main.TPS);
        ball_data.pos.y -= (ball_data.velocity.y / main.TPS);

        if (ball_data.pos.x <= 0 or ball_data.pos.x >= main.WINDOW_WIDTH) {
            ball_data.velocity.x *= -1 * MASS_FACTOR;
            ball_data.pos.x = @min(@max(ball_data.pos.x, 0), main.WINDOW_WIDTH);
        }
        if (ball_data.pos.y <= 0 or ball_data.pos.y >= main.WINDOW_HEIGHT) {
            ball_data.velocity.y *= -1 * MASS_FACTOR;
            ball_data.pos.y = @min(@max(ball_data.pos.y, 0), main.WINDOW_HEIGHT);
        }
    }
}

fn calcAcceleration(velocity: *models.Vec2) void {
    velocity.y -= GRAVITY;
}
