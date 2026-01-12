const Clay = @import("zclay");

pub fn drawLayout() []Clay.RenderCommand {
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
            Clay.text("Hi_from_clay", .{ .font_size = 24, .color = .{ 0, 255, 255, 255 } });
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

    return Clay.endLayout();
}
