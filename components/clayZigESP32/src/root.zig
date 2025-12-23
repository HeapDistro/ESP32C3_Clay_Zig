const std = @import("std");
const builtin = @import("builtin");
const spi = @cImport({
    @cInclude("c_main.h");
});

const clay = @import("zclay");

pub const std_options: std.Options = .{ .logFn = logFn };

fn logFn(comptime message_level: std.log.Level, comptime scope: @TypeOf(.enum_literal), comptime format: []const u8, args: anytype) void {
    _ = message_level;
    _ = scope;
    _ = format;
    _ = args;
}
const truetype = @import("truetype");
const ttf = truetype.load(@embedFile("font")) catch unreachable;
const scale = ttf.scaleForPixelHeight(20);

const Bitmap = struct {
    const HEIGHT = 240;
    const WIDTH = 320;
    bitmap: [HEIGHT][WIDTH]u16,
    const DPI: u8 = 143; //TODO: should be a comptime calculation based off aspect ration and screen size
};

var allocMem: [50000]u8 = @splat(0);
var library_alloc_buffer: [10000]u8 = @splat(0);

var linesOrg: [2]u16 = .{0} ** 2;
var lines: [*c][*c]u16 = @as([*c][*c]u16, @ptrCast(@alignCast(&linesOrg)));
const PARALLEL_LINES: comptime_int = 16;
//BLUE 5 bits RED 5 bits GREEN 6 bits
var frame: Bitmap = .{ .bitmap = @splat(@splat(0)) };

pub export fn app_main() void {
    // Init allocator
    clay.setMaxElementCount(20);
    const minMemorySize: u32 = clay.minMemorySize();
    if (minMemorySize > @sizeOf(@TypeOf(allocMem))) @panic("Clay minimum memory size is bigger than given buffer.");
    const arena: clay.Arena = clay.createArenaWithCapacityAndMemory(&allocMem);
    const dimensions: clay.Dimensions = .{ .h = 240, .w = 320 };
    const clayError: clay.ErrorHandler = .{ .error_handler_function = null };
    _ = clay.initialize(arena, dimensions, clayError);
    clay.setMeasureTextFunction(void, {}, measureText);

    spi.init_spi(lines);

    while (true) {
        // TODO: If touch is ever implemented update the pointer state here
        //clay.Clay_SetPointerState()
        //clay.UpdateScrollContainers()

        clay.beginLayout();

        clay.UI()(
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
            clay.UI()(
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
                clay.text("Clay - UI Library\n", .{ .font_size = 24, .color = .{ 0, 255, 255, 255 } });
                clay.UI()(
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

        const render_commands: []clay.RenderCommand = clay.endLayout();
        clayRender(render_commands);
        sendRender();
    }
}

// TODO: this text rendering is not yet implemented
fn measureText(clay_text: []const u8, config: *clay.TextElementConfig, user_data: void) clay.Dimensions {
    _ = clay_text;
    _ = config;
    _ = user_data;
    return .{ .w = 2, .h = 3 };
}

fn bitmapDrawRectangle(
    bitmap: *Bitmap,
    startX: u16,
    startY: u16,
    width: u16,
    height: u16,
    bckgColor: clay.Color,
    border: clay.BoundingBox,
) void {
    const color: u16 = @as(u16, @intFromFloat(bckgColor[0])) << 11 | @as(u16, @intFromFloat(bckgColor[1])) << 6 | @as(u16, @intFromFloat(bckgColor[2]));
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

fn clayRender(render_commands: []clay.RenderCommand) void {
    const fullWindow: clay.BoundingBox = .{ .y = 0, .x = 0, .height = Bitmap.HEIGHT, .width = Bitmap.WIDTH };
    var scissorBox: clay.BoundingBox = fullWindow;

    for (render_commands) |command| {
        const bounding_box: clay.BoundingBox = .{
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
                //var it = (std.unicode.Utf8View.init(command.render_data.text.string_contents.base_chars[0..@intCast(command.render_data.text.string_contents.length)]) catch unreachable).iterator();
                var it = (std.unicode.Utf8View.init("Ola") catch unreachable).iterator();
                var f_idx: usize = 150;
                while (it.nextCodepoint()) |codepoint| : (f_idx += 20) {
                    if (ttf.codepointGlyphIndex(codepoint)) |glyph| {
                        buffer.clearRetainingCapacity();
                        const dims = ttf.glyphBitmap(fba_allocator, &buffer, glyph, scale, scale) catch |err| switch (err) {
                            // Trap errors for debugging
                            error.OutOfMemory => while (true) {},
                            error.GlyphNotFound => while (true) {}, // error being called ???
                            error.Charstring => while (true) {},
                        };
                        const pixels = buffer.items;
                        for (0..dims.height) |i| {
                            //const y_base: usize = @intFromFloat(bounding_box.y);
                            const y_base: usize = 100;
                            for (0..dims.width) |j| {
                                //const x_base: usize = @intFromFloat(bounding_box.x);
                                const x_base: usize = f_idx;
                                frame.bitmap[y_base + j][x_base + i] = pixels[j * dims.width + i] >> 5;
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
                const data: clay.RectangleRenderData = command.render_data.rectangle;
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
                const data: clay.BorderRenderData = command.render_data.border;
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
    var sendingLine: bool = false;
    var line: u1 = 0;
    var y: usize = 0;
    while (y < 240) : (y += PARALLEL_LINES) {
        if (sendingLine) {
            spi.send_line_finish();
            sendingLine = true;
        }

        var linePtr: [*c]u16 = lines[line];

        for (y..y + PARALLEL_LINES) |_y| {
            for (0..Bitmap.WIDTH) |x| {
                linePtr.* = frame.bitmap[_y][x];
                linePtr = linePtr + 1;
            }
        }

        line = if (line == 0) 1 else 0;
        spi.send_lines(@as(c_int, @intCast(y)), lines[line]);
    }
}
