const std = @import("std");
const builtin = @import("builtin");
const SPI = @cImport({
    @cInclude("c_main.h");
});

const Clay = @import("zclay");
const ClayLayout = @import("clay_layout.zig");

pub const std_options: std.Options = .{ .logFn = logFn };

fn logFn(comptime message_level: std.log.Level, comptime scope: @TypeOf(.enum_literal), comptime format: []const u8, args: anytype) void {
    _ = message_level;
    _ = scope;
    _ = format;
    _ = args;
}
const TrueType = @import("TrueType");
const ttf = TrueType.load(@embedFile("font")) catch unreachable;
const font_pixel_height = 20;
const ttf_scale = ttf.scaleForPixelHeight(font_pixel_height);

const Bitmap = struct {
    const DisplayColor = packed struct(u16) { green: u6, red: u5, blue: u5 };
    const HEIGHT = 240;
    const WIDTH = 320;
    bitmap: [HEIGHT][WIDTH]DisplayColor,
    fn init() Bitmap {
        return .{ .bitmap = @splat(@splat(.{ .red = 0, .blue = 0, .green = 0 })) };
    }
};
var frame: Bitmap = Bitmap.init();

var alloc_mem: [50000]u8 = @splat(0);
var library_alloc_buffer: [10000]u8 = @splat(0);

var lines_org: [2]u16 = @splat(0);
var lines: [*c][*c]u16 = @as([*c][*c]u16, @ptrCast(@alignCast(&lines_org)));
const PARALLEL_LINES: comptime_int = 16;

pub export fn app_main() void {
    // Init allocator
    Clay.setMaxElementCount(20);
    const min_memory_size: u32 = Clay.minMemorySize();
    if (min_memory_size > @sizeOf(@TypeOf(alloc_mem))) @panic("Clay minimum memory size is bigger than given buffer.");
    const arena: Clay.Arena = Clay.createArenaWithCapacityAndMemory(&alloc_mem);
    const dimensions: Clay.Dimensions = .{ .h = 240, .w = 320 };
    const clay_error: Clay.ErrorHandler = .{ .error_handler_function = null };
    _ = Clay.initialize(arena, dimensions, clay_error);
    Clay.setMeasureTextFunction(void, {}, measureText);

    SPI.init_spi(lines);

    while (true) {
        // TODO: If touch is ever implemented update the pointer state here
        //Clay.Clay_SetPointerState()
        //Clay.UpdateScrollContainers()

        clayRender(ClayLayout.drawLayout());
        sendRender();
    }
}

// TODO: this text rendering is not yet implemented
fn measureText(clay_text: []const u8, config: *Clay.TextElementConfig, user_data: void) Clay.Dimensions {
    _ = clay_text;
    _ = config;
    _ = user_data;
    return .{ .w = 2, .h = 3 };
}

inline fn clayColorToDisplayColor(color: Clay.Color) Bitmap.DisplayColor {
    //TODO: why does the following code cause an illegal instruction?
    // return .{
    //     .red = @as(u5, @intFromFloat(color[0])),
    //     .green = @as(u6, @intFromFloat(color[1])),
    //     .blue = @as(u5, @intFromFloat(color[2])),
    // };
    return @bitCast(@as(u16, @intFromFloat(color[0])) << 11 | @as(u16, @intFromFloat(color[2])) << 6 | @as(u16, @intFromFloat(color[1])));
}

fn bitmapDrawRectangle(
    bitmap: *Bitmap,
    start_x: u16,
    start_y: u16,
    width: u16,
    height: u16,
    bckg_color: Clay.Color,
    border: Clay.BoundingBox,
) void {
    const color: Bitmap.DisplayColor = clayColorToDisplayColor(bckg_color);
    for (start_x..start_x + width) |x| {
        for (start_y..start_y + height) |y| {
            if (x >= @as(u16, @intFromFloat(border.x)) and
                x < @as(u16, @intFromFloat(border.x + border.width)) and
                y >= @as(u16, @intFromFloat(border.y)) and
                y < @as(u16, @intFromFloat(border.y + border.height)))
            {
                bitmap.bitmap[y][x] = color;
            }
        }
    }
}

fn clayRender(render_commands: []Clay.RenderCommand) void {
    const full_window: Clay.BoundingBox = .{ .y = 0, .x = 0, .height = Bitmap.HEIGHT, .width = Bitmap.WIDTH };
    var scissor_box: Clay.BoundingBox = full_window;

    for (render_commands) |command| {
        const bounding_box: Clay.BoundingBox = .{
            .x = command.bounding_box.x,
            .y = command.bounding_box.y,
            .height = command.bounding_box.height,
            .width = command.bounding_box.width,
        };
        switch (command.command_type) {
            .none => {},
            .text => {
                var fba = std.heap.FixedBufferAllocator.init(&library_alloc_buffer);
                const fba_allocator = fba.allocator();
                var buffer: std.ArrayListUnmanaged(u8) = .empty;
                var it = (std.unicode.Utf8View.init(command.render_data.text.string_contents.base_chars[0..@intCast(command.render_data.text.string_contents.length)]) catch unreachable).iterator();
                var f_idx: usize = 100;
                const y_idx: usize = 0;
                while (it.nextCodepoint()) |codepoint| : (f_idx += 15) {
                    if (codepoint == '\n') {
                        //y_idx += 100;
                        f_idx = 100;
                        continue;
                    }
                    if (ttf.codepointGlyphIndex(codepoint)) |glyph| {
                        buffer.clearRetainingCapacity();
                        const dims = ttf.glyphBitmap(fba_allocator, &buffer, glyph, ttf_scale, ttf_scale) catch |err| switch (err) {
                            // Trap errors for debugging
                            error.OutOfMemory => while (true) {},
                            error.GlyphNotFound => while (true) {}, // Space
                            error.Charstring => while (true) {},
                        };
                        const pixels = buffer.items;
                        for (0..dims.height) |i| { //16
                            const y_base: usize = @as(usize, @intFromFloat(bounding_box.y)) + y_idx;
                            for (0..dims.width) |j| {
                                const x_base: usize = @as(usize, @intFromFloat(bounding_box.x)) + f_idx;
                                //const x_base: usize = f_idx;
                                if ((y_base + i) >= Bitmap.HEIGHT or (x_base + j) >= Bitmap.WIDTH) {
                                    // font is outside of frame
                                    continue;
                                }
                                //TODO: below doesnt take into account anti-aliasing...
                                frame.bitmap[y_base + i][x_base + j] = if (pixels[i * dims.width + j] != 0) clayColorToDisplayColor(command.render_data.text.text_color) else continue;
                            }
                        }
                    }
                }
            },
            .image => {}, // NOT IMPLEMENTED
            .scissor_start => {
                scissor_box = bounding_box;
            },
            .scissor_end => {
                scissor_box = full_window;
            },
            .rectangle => {
                const data: Clay.RectangleRenderData = command.render_data.rectangle;
                bitmapDrawRectangle(
                    &frame,
                    @intFromFloat(bounding_box.x),
                    @intFromFloat(bounding_box.y),
                    @intFromFloat(bounding_box.width),
                    @intFromFloat(bounding_box.height),
                    data.background_color,
                    scissor_box,
                );
            },
            .border => {
                const data: Clay.BorderRenderData = command.render_data.border;
                // Left border
                if (data.width.left > 0) {
                    bitmapDrawRectangle(
                        &frame,
                        @intFromFloat(bounding_box.x),
                        @intFromFloat(bounding_box.y + data.corner_radius.top_left),
                        data.width.left,
                        @intFromFloat(bounding_box.height - data.corner_radius.top_left - data.corner_radius.bottom_left),
                        data.color,
                        scissor_box,
                    );
                }
                // Right border
                if (data.width.right > 0) {
                    bitmapDrawRectangle(
                        &frame,
                        @as(u16, @intFromFloat(bounding_box.x + bounding_box.width)) - data.width.right,
                        @intFromFloat(bounding_box.y + data.corner_radius.top_right),
                        data.width.right,
                        @intFromFloat(bounding_box.height - data.corner_radius.top_right - data.corner_radius.bottom_right),
                        data.color,
                        scissor_box,
                    );
                }
                // Top border
                if (data.width.top > 0) {
                    bitmapDrawRectangle(
                        &frame,
                        @intFromFloat(bounding_box.x + data.corner_radius.top_left),
                        @intFromFloat(bounding_box.y),
                        @intFromFloat(bounding_box.width - data.corner_radius.top_left - data.corner_radius.top_right),
                        data.width.top,
                        data.color,
                        scissor_box,
                    );
                }
                // Bottom border
                if (data.width.bottom > 0) {
                    bitmapDrawRectangle(
                        &frame,
                        @intFromFloat(bounding_box.x + data.corner_radius.bottom_left),
                        @as(u16, @intFromFloat(bounding_box.y + bounding_box.height)) - data.width.bottom,
                        @intFromFloat(bounding_box.width - data.corner_radius.bottom_left - data.corner_radius.bottom_right),
                        data.width.bottom,
                        data.color,
                        scissor_box,
                    );
                }
            },
            .custom => {},
        }
    }
}

fn sendRender() void {
    var line: u1 = 0;
    var y: usize = 0;
    while (y < 240) : (y += PARALLEL_LINES) {
        var line_ptr: [*c]u16 = lines[line];

        for (y..y + PARALLEL_LINES) |_y| {
            for (0..Bitmap.WIDTH) |x| {
                line_ptr.* = @bitCast(frame.bitmap[_y][x]);
                line_ptr = line_ptr + 1;
            }
        }

        line = if (line == 0) 1 else 0;
        SPI.send_lines(@as(c_int, @intCast(y)), lines[line]);
        SPI.send_line_finish();
    }
}
