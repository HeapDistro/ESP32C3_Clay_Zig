const std = @import("std");
const builtin = @import("builtin");
const SPI = @cImport({
    @cInclude("c_main.h");
});

const Clay = @import("zclay");

pub const std_options: std.Options = .{ .logFn = logFn };

fn logFn(comptime message_level: std.log.Level, comptime scope: @TypeOf(.enum_literal), comptime format: []const u8, args: anytype) void {
    _ = message_level;
    _ = scope;
    _ = format;
    _ = args;
}
const TrueType = @import("TrueType");
const ttf = TrueType.load(@embedFile("font")) catch unreachable;
const scale = ttf.scaleForPixelHeight(20);

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

var allocMem: [50000]u8 = @splat(0);
var library_alloc_buffer: [10000]u8 = @splat(0);

var linesOrg: [2]u16 = @splat(0);
var lines: [*c][*c]u16 = @as([*c][*c]u16, @ptrCast(@alignCast(&linesOrg)));
const PARALLEL_LINES: comptime_int = 16;

pub export fn app_main() void {
    // Init allocator
    Clay.setMaxElementCount(20);
    const minMemorySize: u32 = Clay.minMemorySize();
    if (minMemorySize > @sizeOf(@TypeOf(allocMem))) @panic("Clay minimum memory size is bigger than given buffer.");
    const arena: Clay.Arena = Clay.createArenaWithCapacityAndMemory(&allocMem);
    const dimensions: Clay.Dimensions = .{ .h = 240, .w = 320 };
    const clayError: Clay.ErrorHandler = .{ .error_handler_function = null };
    _ = Clay.initialize(arena, dimensions, clayError);
    Clay.setMeasureTextFunction(void, {}, measureText);

    SPI.init_spi(lines);

    while (true) {
        // TODO: If touch is ever implemented update the pointer state here
        //Clay.Clay_SetPointerState()
        //Clay.UpdateScrollContainers()

        Clay.beginLayout();

        Clay.UI()(
            .{
                .id = .ID("OuterContainer"),
                .layout = .{
                    .sizing = .{ .w = .grow, .h = .grow },
                    .padding = .all(4),
                    .child_gap = 4,
                },
                .background_color = .{ 250, 0, 255, 255 },
            },
        )({
            Clay.UI()(
                .{
                    .id = .ID("SideBar"),
                    .layout = .{
                        .direction = .top_to_bottom,
                        .sizing = .{ .w = .fixed(100), .h = .fixed(200) },
                        .padding = .all(4),
                        .child_gap = 4,
                    },
                },
            )({
                Clay.text("ClayO\nTest", .{ .font_size = 24, .color = .{ 0, 255, 255, 255 } });
                Clay.UI()(
                    .{
                        .id = .ID("MainContent"),
                        .layout = .{
                            .sizing = .{ .w = .grow, .h = .grow },
                        },
                        .background_color = .{ 127, 127, 0, 255 },
                    },
                )({});
            });
        });

        const render_commands: []Clay.RenderCommand = Clay.endLayout();
        clayRender(render_commands);
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
    startX: u16,
    startY: u16,
    width: u16,
    height: u16,
    bckgColor: Clay.Color,
    border: Clay.BoundingBox,
) void {
    const color: Bitmap.DisplayColor = clayColorToDisplayColor(bckgColor);
    for (startX..startX + width) |x| {
        for (startY..startY + height) |y| {
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
    const fullWindow: Clay.BoundingBox = .{ .y = 0, .x = 0, .height = Bitmap.HEIGHT, .width = Bitmap.WIDTH };
    var scissorBox: Clay.BoundingBox = fullWindow;

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
                var y_idx: usize = 0;
                while (it.nextCodepoint()) |codepoint| : (f_idx += 15) {
                    if (codepoint == '\n') {
                        y_idx += 15;
                        continue;
                    }
                    if (ttf.codepointGlyphIndex(codepoint)) |glyph| {
                        buffer.clearRetainingCapacity();
                        const dims = ttf.glyphBitmap(fba_allocator, &buffer, glyph, scale, scale) catch |err| switch (err) {
                            // Trap errors for debugging
                            error.OutOfMemory => while (true) {},
                            error.GlyphNotFound => while (true) {}, // Space
                            error.Charstring => while (true) {},
                        };
                        const pixels = buffer.items;
                        for (0..dims.height) |i| {
                            //const y_base: usize = @intFromFloat(bounding_box.y);
                            const y_base: usize = 100 + y_idx;
                            for (0..dims.width) |j| {
                                //const x_base: usize = @intFromFloat(bounding_box.x);
                                const x_base: usize = f_idx;
                                //TODO: below doesnt take into account anti-aliasing...
                                frame.bitmap[y_base + i][x_base + j] = if (pixels[i * dims.width + j] != 0) clayColorToDisplayColor(command.render_data.text.text_color) else continue;
                            }
                        }
                    }
                }
            },
            .image => {}, // NOT IMPLEMENTED
            .scissor_start => {
                scissorBox = bounding_box;
            },
            .scissor_end => {
                scissorBox = fullWindow;
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
                    scissorBox,
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
                        scissorBox,
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
                        scissorBox,
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
                        scissorBox,
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
                        scissorBox,
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
        var linePtr: [*c]u16 = lines[line];

        for (y..y + PARALLEL_LINES) |_y| {
            for (0..Bitmap.WIDTH) |x| {
                linePtr.* = @bitCast(frame.bitmap[_y][x]);
                linePtr = linePtr + 1;
            }
        }

        line = if (line == 0) 1 else 0;
        SPI.send_lines(@as(c_int, @intCast(y)), lines[line]);
        SPI.send_line_finish();
    }
}
