const std = @import("std");
const spi = @cImport({
    @cInclude("c_main.h");
});
const clay = @cImport({
    @cInclude("clay.h");
});

extern fn send_line_finish() void;

extern fn send_lines(ypos: c_int, linedata: *c_ushort) void;

var allocMem: [5000]u8 = [_]u8{0} ** 5000;
var fixedAllocator: std.heap.FixedBufferAllocator = undefined;
var allocator: std.mem.Allocator = undefined;

var lines: [*c][*c]u16 = undefined;
const PARALLEL_LINES: comptime_int = 16;

pub export fn app_main() void {
    // Init allocator
    fixedAllocator = std.heap.FixedBufferAllocator.init(&allocMem);
    allocator = fixedAllocator.allocator();

    const minMemorySize: u32 = clay.Clay_MinMemorySize();
    const memory = allocator.alloc(u8, minMemorySize) catch return;
    //defer allocator.free(memory);
    const arena: clay.Clay_Arena = clay.Clay_CreateArenaWithCapacityAndMemory(minMemorySize,@as(*anyopaque,@ptrCast(memory)));
    const dimensions: clay.Clay_Dimensions = .{.height = 240, .width= 320};
    const clayError: clay.Clay_ErrorHandler = .{ .errorHandlerFunction = null};
    _ = clay.Clay_Initialize(arena, dimensions, clayError);
    //clay.setMeasureTextFunction(void, {}, renderer.measureText);

    spi.init_spi(lines);
    while (true) {
        //Draw somthing here
        spi.display_pretty_colors(lines);
        // Call renderer

    }
}

fn clayRender(render_commands: *clay.ClayArray(clay.RenderCommand)) !void {
    var i: usize = 0;
    while (i < render_commands.length) : (i += 1) {
        const render_command = clay.renderCommandArrayGet(render_commands, @intCast(i));
        //const bounding_box = render_command.bounding_box;
        switch (render_command.command_type) {
            .none => {},
            .text => {
            },
            .image => {
            },
            .scissor_start => {
            },
            .scissor_end => {},
            .rectangle => {
            },
            .border => {
            },
            .custom => {
            },
        }
    }
}

fn sendRender() void {
    const local = struct {
        sendingLine: bool = false,
        line: u1 = 0,
    };
    var y: usize = 0;
    while (y < 240) : (y += PARALLEL_LINES) {
        //try_to_render_something_fr(y);
        if (!local.sendingLine) {
            send_line_finish();
            local.sendingLine = true;
        }

        send_lines(y, lines[local.line]);
        local.line = if (local.line == 0) 1 else 0;
    }
}

