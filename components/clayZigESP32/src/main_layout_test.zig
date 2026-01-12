const std = @import("std");
const rl = @import("raylib");
const cl = @import("zclay");
const renderer = @import("raylib_render_clay.zig");
const ClayLayout = @import("clay_layout.zig");

var window_height: isize = 0;
var window_width: isize = 0;
var mobile_screen: bool = false;

const FONT_ID_BODY_16 = 0;
const FONT_ID_TITLE_52 = 1;
const FONT_ID_TITLE_48 = 2;
const FONT_ID_TITLE_36 = 3;
const FONT_ID_TITLE_32 = 4;
const FONT_ID_BODY_36 = 5;
const FONT_ID_BODY_30 = 6;
const FONT_ID_BODY_28 = 7;
const FONT_ID_BODY_24 = 8;
const FONT_ID_TITLE_56 = 9;

fn loadFont(file_data: ?[]const u8, font_id: u16, font_size: i32) !void {
    renderer.raylib_fonts[font_id] = try rl.loadFontFromMemory(".ttf", file_data, font_size * 2, null);
    rl.setTextureFilter(renderer.raylib_fonts[font_id].?.texture, .bilinear);
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // init clay
    const min_memory_size: u32 = cl.minMemorySize();
    const memory = try allocator.alloc(u8, min_memory_size);
    defer allocator.free(memory);
    const arena: cl.Arena = cl.createArenaWithCapacityAndMemory(memory);
    _ = cl.initialize(arena, .{ .h = 240, .w = 320 }, .{});
    cl.setMeasureTextFunction(void, {}, renderer.measureText);

    // init raylib
    rl.setConfigFlags(.{
        .msaa_4x_hint = true,
        .window_resizable = true,
    });
    rl.initWindow(320, 240, "Raylib zig Example");
    rl.setTargetFPS(60);

    // load assets
    try loadFont(@embedFile("font"), FONT_ID_TITLE_56, 56);
    try loadFont(@embedFile("font"), FONT_ID_TITLE_52, 52);
    try loadFont(@embedFile("font"), FONT_ID_TITLE_48, 48);
    try loadFont(@embedFile("font"), FONT_ID_TITLE_36, 36);
    try loadFont(@embedFile("font"), FONT_ID_TITLE_32, 32);
    try loadFont(@embedFile("font"), FONT_ID_BODY_36, 36);
    try loadFont(@embedFile("font"), FONT_ID_BODY_30, 30);
    try loadFont(@embedFile("font"), FONT_ID_BODY_28, 28);
    try loadFont(@embedFile("font"), FONT_ID_BODY_24, 24);
    try loadFont(@embedFile("font"), FONT_ID_BODY_16, 16);

    var animation_lerp_value: f32 = -1.0;
    var debug_mode_enabled = false;
    while (!rl.windowShouldClose()) {
        if (rl.isKeyPressed(.d)) {
            debug_mode_enabled = !debug_mode_enabled;
            cl.setDebugModeEnabled(debug_mode_enabled);
        }

        animation_lerp_value += rl.getFrameTime();
        if (animation_lerp_value > 1) {
            animation_lerp_value = animation_lerp_value - 2;
        }

        window_width = rl.getScreenWidth();
        window_height = rl.getScreenHeight();
        mobile_screen = (window_width - if (debug_mode_enabled) @as(i32, @intCast(cl.Clay__debugViewWidth)) else 0) < 750;

        const mouse_pos = rl.getMousePosition();
        cl.setPointerState(.{
            .x = mouse_pos.x,
            .y = mouse_pos.y,
        }, rl.isMouseButtonDown(.left));

        const scroll_delta = rl.getMouseWheelMoveV().multiply(.{ .x = 6, .y = 6 });
        cl.updateScrollContainers(
            false,
            .{ .x = scroll_delta.x, .y = scroll_delta.y },
            rl.getFrameTime(),
        );

        cl.setLayoutDimensions(.{ .w = @floatFromInt(window_width), .h = @floatFromInt(window_height) });
        const render_commands = ClayLayout.drawLayout();

        rl.beginDrawing();
        try renderer.clayRaylibRender(render_commands, allocator);
        rl.endDrawing();
    }
}
