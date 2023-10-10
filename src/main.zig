const std = @import("std");
const rl = @import("raylib");
const rg = @import("raygui");
const math = std.math;

const Width: i32 = 1200;
const Height: i32 = @divTrunc(Width, 2);
const HalfWidth: f32 = Width / 2;
const HalfHeight: f32 = Height / 2;

const uiScale: f32 = (@as(f32, @floatFromInt(Width)) / 2400.0);
const uiWidth = 315 * uiScale;
const uiHeight = 60 * uiScale;
const uiBoxSize = 40 * uiScale;
const xCol = Width - (uiWidth + (85 * uiScale));

const gravity: f32 = 9.81 * 50;

var collisionDampener: f32 = 0.85;

var particleSize: f32 = 50 * uiScale;
var particleSpacing: f32 = 3 * uiScale;

var numParticles: f32 = 30;

const Particle = struct {
    position: rl.Vector2,
    velocity: rl.Vector2,

    fn init(x: f32, y: f32) Particle {
        return Particle{
            .position = .{ .x = x, .y = y },
            .velocity = .{ .x = 0, .y = 0 },
        };
    }
};

fn init(particles: *std.ArrayList(Particle)) void {
    const particlesPerRow: u32 = @intFromFloat(math.sqrt(numParticles));
    const particlesPerCol: u32 = (@as(u32, @intFromFloat(numParticles)) - 1) / particlesPerRow + 1;
    const spacing: f32 = particleSize * 2 + particleSpacing;
    particles.clearRetainingCapacity();

    for (0..@as(u32, @intFromFloat(numParticles))) |i| {
        const x: f32 = (@as(f32, @floatFromInt(i % particlesPerRow)) - @as(f32, @floatFromInt(particlesPerRow)) / 2.0 + 0.5) * spacing;
        const y: f32 = (@as(f32, @floatFromInt(i / particlesPerRow)) - @as(f32, @floatFromInt(particlesPerCol)) / 2.0 + 0.5) * spacing;
        particles.append(Particle.init(x + HalfWidth, y + HalfHeight)) catch unreachable;
    }
}

fn update(delta: f32, width: f32, height: f32, particles: *std.ArrayList(Particle), run: *bool, reset: *bool) void {
    for (0..particles.items.len) |i| {
        if (run.*) {
            particles.items[i].velocity.y += gravity * delta;
            particles.items[i].position.y += particles.items[i].velocity.y * delta;
            resolveCollisions(&particles.items[i], width, height);
            reset.* = false;
        }
        rl.DrawCircleV(particles.items[i].position, particleSize, rl.BLUE);
    }
    if (reset.*) {
        particles.resize(@as(usize, @intFromFloat(numParticles))) catch unreachable;
        init(particles);
        run.* = false;
    }
}

fn resolveCollisions(particle: *Particle, width: f32, height: f32) void {
    const xbound = width - particleSize;
    if (@fabs(particle.position.x) > xbound) {
        particle.position.x = xbound * math.sign(particle.position.x);
        particle.velocity.x *= -1 * collisionDampener;
    }
    const ybound = height - particleSize;
    if (@fabs(particle.position.y) > ybound) {
        particle.position.y = ybound * math.sign(particle.position.y);
        particle.velocity.y *= -1 * collisionDampener;
    }
}

pub fn main() !void {
    // rl.SetConfigFlags(rl.ConfigFlags{ .FLAG_WINDOW_RESIZABLE = true });
    rl.InitWindow(Width, Height, "Fluid Sim");
    defer rl.CloseWindow();
    rl.SetTargetFPS(60);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var particles = std.ArrayList(Particle).initCapacity(allocator, @as(usize, @intFromFloat(@floor(numParticles)))) catch unreachable;
    init(&particles);
    defer particles.deinit();

    var screenWidth: f32 = Width;
    var screenHeight: f32 = Height;

    var run = false;
    var reset = false;
    var colBoxX: f32 = screenWidth;
    var colBoxY: f32 = screenHeight;
    while (!rl.WindowShouldClose()) {
        rl.BeginDrawing();
        defer rl.EndDrawing();
        screenWidth = @as(f32, @floatFromInt(rl.GetScreenWidth())) / 2;
        screenHeight = @as(f32, @floatFromInt(rl.GetScreenHeight())) / 2;
        rl.ClearBackground(rl.RAYWHITE);
        rl.DrawFPS(10, 10);
        var deltaTime = rl.GetFrameTime();
        rl.DrawRectangleLines(@as(i32, @intFromFloat(screenWidth - colBoxX / 2)), @as(i32, @intFromFloat(screenHeight - colBoxY / 2)), @as(i32, @intFromFloat(colBoxX)), @as(i32, @intFromFloat(colBoxY)), rl.BLACK);
        update(deltaTime, colBoxX + screenWidth - colBoxX / 2, colBoxY + screenHeight - colBoxY / 2, &particles, &run, &reset);
        _ = rg.GuiSliderBar(.{ .x = xCol, .y = 20 + (uiHeight * 0), .width = uiWidth, .height = uiHeight }, "Bounding Box Width", "", &colBoxX, 0, screenWidth * 2);
        _ = rg.GuiSliderBar(.{ .x = xCol, .y = 30 + (uiHeight * 1), .width = uiWidth, .height = uiHeight }, "Bounding Box Height", "", &colBoxY, 0, screenHeight * 2);
        _ = rg.GuiSliderBar(.{ .x = xCol, .y = 40 + (uiHeight * 2), .width = uiWidth, .height = uiHeight }, "Spacing", "", &particleSpacing, 0, 100 * uiScale);
        _ = rg.GuiSliderBar(.{ .x = xCol, .y = 50 + (uiHeight * 3), .width = uiWidth, .height = uiHeight }, "Size", "", &particleSize, 1, 350 * uiScale);
        _ = rg.GuiSliderBar(.{ .x = xCol, .y = 60 + (uiHeight * 4), .width = uiWidth, .height = uiHeight }, "Quantity", "", &numParticles, 1, 1000);
        _ = rg.GuiSliderBar(.{ .x = xCol, .y = 70 + (uiHeight * 5), .width = uiWidth, .height = uiHeight }, "Collision Dampening", "", &collisionDampener, 0, 1);
        _ = rg.GuiCheckBox(.{ .x = xCol, .y = 80 + (uiHeight * 6), .width = uiBoxSize, .height = uiBoxSize }, "Run", &run);
        _ = rg.GuiCheckBox(.{ .x = xCol, .y = 80 + (uiHeight * 7), .width = uiBoxSize, .height = uiBoxSize }, "Reset", &reset);
        const msg = "Hello zig! You created your first window.";
        rl.DrawText(msg, @as(i32, @intFromFloat(screenWidth)) - @as(i32, 5 * msg.len), @as(i32, @intFromFloat(screenHeight)) - 200, 20, rl.BLACK);
        if (rl.IsKeyDown(.KEY_Q)) {
            break;
        }
    }
    std.debug.print("exiting...\n", .{});
}
