const rl = @import("raylib");

pub const Vec2 = extern struct {
    x: f32,
    y: f32,
};

pub const BallData = extern struct {
    pos: Vec2,
    velocity: Vec2,
    color: rl.Color,
};
