const std = @import("std");
const spi = @cImport({
    @cInclude("c_main.h");
});
const clay = @cImport({
    @cInclude("clay.h");
});

const Bitmap = struct {
    const HEIGHT = 240;
    const WIDTH = 320;
    bitmap: [HEIGHT][WIDTH]u16,
};

var allocMem: [5000]u8 = [_]u8{0} ** 5000;
var linesOrg: [2]u16 = .{0} ** 2;
var lines: [*c][*c]u16 = @as([*c][*c]u16, @alignCast(@ptrCast(&linesOrg)));
const PARALLEL_LINES: comptime_int = 16;
//BLUE 5 bits RED 5 bits GREEN 6 bits
var frame: Bitmap = .{ .bitmap = .{.{0b0000000000111111} ** Bitmap.WIDTH} ** Bitmap.HEIGHT };

pub export fn app_main() void {
    // Init allocator
    clay.Clay_SetMaxElementCount(1);
    const minMemorySize: u32 = clay.Clay_MinMemorySize();
    if (minMemorySize > @sizeOf(@TypeOf(allocMem))) return;
    const arena: clay.Clay_Arena = clay.Clay_CreateArenaWithCapacityAndMemory(@sizeOf(@TypeOf(allocMem)), @as(*anyopaque, @ptrCast(&allocMem)));
    const dimensions: clay.Clay_Dimensions = .{ .height = 240, .width = 320 };
    const clayError: clay.Clay_ErrorHandler = .{ .errorHandlerFunction = null };
    _ = clay.Clay_Initialize(arena, dimensions, clayError);
    //clay.setMeasureTextFunction(void, {}, renderer.measureText);

    spi.init_spi(lines);
    while (true) {
        sendRender();
    }
}

fn clayRender(render_commands: *clay.ClayArray(clay.RenderCommand)) !void {
    var i: usize = 0;
    while (i < render_commands.length) : (i += 1) {
        const render_command = clay.renderCommandArrayGet(render_commands, @intCast(i));
        //const bounding_box = render_command.bounding_box;
        switch (render_command.command_type) {
            .none => {},
            .text => {},
            .image => {},
            .scissor_start => {},
            .scissor_end => {},
            .rectangle => {},
            .border => {},
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
