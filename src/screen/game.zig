const std = @import("std");
const screen = @import("../screen.zig");
const Screen = screen.Screen;
const platform = @import("../platform.zig");
const gui = platform.gui;
const Vec = platform.Vec;
const Vec2f = platform.Vec2f;
const vec2f = platform.vec2f;
const Vec2i = platform.Vec2i;
const vec2us = platform.vec2us;
const vec2i = platform.vec2i;
const Context = platform.Context;
const Renderer = platform.Renderer;
const game = @import("../game.zig");
const World = game.World;
const GridOfLife = game.GridOfLife;
const constants = @import("../constants.zig");

const DEFAULT_GRID_WIDTH = 100;
const DEFAULT_GRID_HEIGHT = 100;
const CELL_WIDTH = 16;
const CELL_HEIGHT = 16;
const MIN_SCALE = 2;
const MAX_SCALE = 1024;

const TEXT_PRESS_RIGHT = "Press → to advance one step";

pub const Game = struct {
    alloc: *std.mem.Allocator,
    screen: Screen,

    quit_pressed: bool = false,
    paused: bool,
    step_once: bool,
    start_cell: Vec2i,
    prev_cell: Vec2i,

    is_selecting: bool,
    select_start_cell: Vec2i,
    grid_clipboard: ?GridOfLife,

    start_pan: ?Vec2i = null,
    start_pan_camera_pos: ?Vec2f = null,
    camera_pos: Vec2f = Vec2f.init(0, 0),
    cursor_pos: Vec2f = Vec2f.init(0, 0),
    scale: f32 = 16.0,
    screen_size: Vec2f = Vec2f.init(0, 0),

    gui: gui.Gui,
    paused_text: *gui.Label,
    generation_text: *gui.Label,

    ticks_per_step: f32 = 10,
    ticks_since_last_step: f32 = 0,
    grid: World,

    pub fn init(alloc: *std.mem.Allocator) !*@This() {
        const self = try alloc.create(@This());
        var grid = World.init(alloc);
        errdefer grid.deinit();
        try grid.set(vec2i(0, 0), true);
        const grid_clipboard = try GridOfLife.init(alloc, .{
            .size = vec2us(0, 0),
            .edge_behaviour = .Dead,
        });
        errdefer grid_clipboard.deinit(alloc);
        self.* = .{
            .alloc = alloc,
            .screen = .{
                .startFn = start,
                .onEventFn = onEvent,
                .updateFn = update,
                .renderFn = render,
                .deinitFn = deinit,
            },
            .paused = true,
            .step_once = false,
            .start_cell = vec2i(-1, -1),
            .prev_cell = vec2i(-1, -1),
            .is_selecting = false,
            .select_start_cell = vec2i(-1, -1),
            .grid_clipboard = null,
            .grid = grid,
            .paused_text = undefined,
            .generation_text = undefined,
            .gui = gui.Gui.init(alloc),
        };
        return self;
    }

    pub fn start(screenPtr: *Screen, context: *Context) void {
        const self = @fieldParentPtr(@This(), "screen", screenPtr);

        self.generation_text = gui.Label.init(&self.gui, std.mem.dupe(self.alloc, u8, "Generation #0") catch unreachable) catch unreachable;
        self.generation_text.text_align = .Left;
        self.generation_text.text_baseline = .Middle;

        self.paused_text = gui.Label.init(&self.gui, "Start") catch unreachable;
        self.paused_text.element.margin = .{
            .left = 10,
            .right = 10,
        };
        self.paused_text.text_align = .Center;
        self.paused_text.text_baseline = .Middle;
        const play_pause_button = gui.Button.init(&self.gui, &self.paused_text.element) catch unreachable;
        play_pause_button.onclick = play_pause_clicked;
        play_pause_button.userdata = @ptrToInt(self);

        const press_right_text = gui.Label.init(&self.gui, TEXT_PRESS_RIGHT) catch unreachable;
        press_right_text.text_align = .Right;
        press_right_text.text_baseline = .Middle;

        const flex = gui.Flexbox.init(&self.gui) catch unreachable;
        flex.cross_align = .End;
        flex.element.margin = .{ .left = 5, .right = 5, .bottom = 2 };
        flex.addChild(&self.generation_text.element) catch unreachable;
        flex.addChild(&play_pause_button.element) catch unreachable;
        flex.addChild(&press_right_text.element) catch unreachable;

        const tool_bar_flex = gui.Flexbox.init(&self.gui) catch unreachable;
        tool_bar_flex.direction = .Col;
        tool_bar_flex.justification = .Start;
        tool_bar_flex.cross_align = .Center;

        for (game.patterns.PREDEFINED) |*pattern| {
            var closure = self.alloc.create(PatternClosure) catch unreachable;
            closure.* = .{
                .game = self,
                .pattern = pattern,
            };

            const pattern_button_label = gui.Label.init(&self.gui, pattern.name) catch unreachable;
            pattern_button_label.element.margin = .{
                .top = 7,
                .left = 5,
                .right = 5,
                .bottom = 7,
            };
            const pattern_button = gui.Button.init(&self.gui, &pattern_button_label.element) catch unreachable;
            pattern_button.element.margin = .{ .top = 5, .left = 5 };
            pattern_button.onclick = PatternClosure.execute;
            pattern_button.userdata = @ptrToInt(closure);

            tool_bar_flex.addChild(&pattern_button.element) catch unreachable;
        }

        const fullscreen_button_label = gui.Label.init(&self.gui, "Fullscreen") catch unreachable;
        fullscreen_button_label.element.margin = .{
            .top = 10,
            .left = 10,
            .right = 10,
            .bottom = 10,
        };
        const fullscreen_button = gui.Button.init(&self.gui, &fullscreen_button_label.element) catch unreachable;
        fullscreen_button.onclick = fullscreen_clicked;
        fullscreen_button.userdata = @ptrToInt(context);

        const fullscreen_button_flex = gui.Flexbox.init(&self.gui) catch unreachable;
        fullscreen_button_flex.direction = .Row;
        fullscreen_button_flex.justification = .End;
        fullscreen_button_flex.cross_align = .Start;
        fullscreen_button_flex.addChild(&fullscreen_button.element) catch unreachable;

        const grid_container = gui.Grid.init(&self.gui) catch unreachable;
        const tool_bar_flex_grid_area = grid_container.addChild(&tool_bar_flex.element) catch unreachable;
        const fullscreen_flex_grid_area = grid_container.addChild(&fullscreen_button_flex.element) catch unreachable;
        const flex_grid_area = grid_container.addChild(&flex.element) catch unreachable;
        grid_container.layout = .{
            .areas = gui.Grid.AreaGrid.init(self.alloc, 2, 2, &[_]?usize{
                tool_bar_flex_grid_area, fullscreen_flex_grid_area,
                tool_bar_flex_grid_area, flex_grid_area,
            }) catch unreachable,
            .row = std.mem.dupe(self.alloc, gui.Grid.Size, &[_]gui.Grid.Size{ .{ .auto = .{} }, .{ .fr = 1 } }) catch unreachable,
        };

        self.gui.root = &grid_container.element;
    }

    fn play_pause_clicked(button: *gui.Button, userdata: ?usize) void {
        const self = @intToPtr(*@This(), userdata.?);
        self.toggle_play_pause();
    }

    fn fullscreen_clicked(button: *gui.Button, userdata: ?usize) void {
        const context = @intToPtr(*Context, userdata.?);
        context.request_fullscreen();
    }

    const PatternClosure = struct {
        game: *Game,
        pattern: *const game.patterns.Pattern,

        fn execute(button: *gui.Button, userdata: ?usize) void {
            const closure = @intToPtr(*@This(), userdata.?);
            if (closure.game.grid_clipboard) |clipboard| {
                clipboard.deinit(closure.game.alloc);
                closure.game.grid_clipboard = null;
            }
            closure.game.grid_clipboard = closure.pattern.to_grid_of_life(closure.game.alloc) catch {
                platform.warn("Could not allocate space for new grid", .{});
                return;
            };
        }
    };

    fn pulsar_clicked(button: *gui.Button, userdata: ?usize) void {
        const self = @intToPtr(*@This(), userdata.?);
        if (self.grid_clipboard) |clipboard| {
            clipboard.deinit(self.alloc);
            self.grid_clipboard = null;
        }
        self.grid_clipboard = game.patterns.PULSAR.to_grid_of_life(self.alloc) catch {
            platform.warn("Could not allocate space for new grid", .{});
            return;
        };
    }

    fn toggle_play_pause(self: *@This()) void {
        self.paused = !self.paused;
        self.paused_text.text = if (self.paused) "Start" else "Stop";
    }

    pub fn onEvent(screenPtr: *Screen, context: *Context, event: platform.Event) void {
        const self = @fieldParentPtr(@This(), "screen", screenPtr);
        if (self.gui.onEvent(context, event)) {
            // The event has been consumed by the UI
            return;
        }
        switch (event) {
            .Quit => platform.quit(),
            .KeyDown => |ev| switch (ev.scancode) {
                .ESCAPE => self.quit_pressed = true,
                .SPACE => self.toggle_play_pause(),
                .RIGHT => self.step_once = true,
                .UP => self.ticks_per_step += 1,
                .DOWN => {
                    self.ticks_per_step -= 1;
                    self.ticks_per_step = std.math.max(self.ticks_per_step, 0);
                },
                .R => if (self.grid_clipboard) |*clipboard| {
                    clipboard.rotate();
                },
                else => {},
            },
            .MouseButtonDown => |ev| switch (ev.button) {
                .Left => if (self.paused) {
                    self.start_cell = self.cursor_pos_to_cell(ev.pos.intToFloat(f32));
                    self.prev_cell = self.start_cell;
                    if (self.grid_clipboard) |clipboard| {
                        const clipboard_center = clipboard.options.size.scalDiv(2).intCast(i32);
                        const dest = platform.Rect(i32).initPosAndSize(self.start_cell.sub(clipboard_center), clipboard.options.size.intCast(i32));
                        const src = platform.Rect(i32).initPosAndSize(Vec(2, i32).init(0, 0), clipboard.options.size.intCast(i32));
                        //self.grid.copy(dest, clipboard, src);
                    } else {
                        self.grid.set(self.start_cell, !self.grid.get(self.start_cell)) catch unreachable;
                    }
                },
                .Middle => {
                    self.start_pan = ev.pos;
                    self.start_pan_camera_pos = self.camera_pos;
                    context.set_cursor(.grabbing);
                },
                .Right => {
                    self.select_start_cell = self.cursor_pos_to_cell(ev.pos.intToFloat(f32));
                    self.is_selecting = true;

                    // get rid of the previous grid_clipboard
                    if (self.grid_clipboard) |clipboard| {
                        clipboard.deinit(self.alloc);
                        self.grid_clipboard = null;
                    }

                    // TODO: chose a cursor for select
                    //context.set_cursor(.grabbing);
                },
                else => {},
            },
            .MouseButtonUp => |ev| switch (ev.button) {
                .Middle => {
                    self.start_pan = null;
                    self.start_pan_camera_pos = null;
                    context.set_cursor(.default);
                },
                .Right => {
                    self.is_selecting = false;
                    context.set_cursor(.default);

                    if (!self.paused) {
                        // Don't copy the grid while the simulation is running, only allow emptying the clipboard
                        return;
                    }

                    // Copy selection to grid clipboard
                    const end_cell = self.cursor_pos_to_cell(ev.pos.intToFloat(f32));
                    var src_rect = platform.Rect(i32).initTwoPos(self.select_start_cell, end_cell);
                    src_rect.max = src_rect.max.add(Vec(2, i32).init(1, 1));

                    if (src_rect.size().x() <= 1 and src_rect.size().y() <= 1) {
                        // Only one cell in the selection, don't copy it
                        return;
                    }

                    const dest_rect = platform.Rect(i32).initPosAndSize(Vec(2, i32).init(0, 0), src_rect.size());

                    self.grid_clipboard = GridOfLife.init(self.alloc, .{
                        .size = dest_rect.size().intCast(usize),
                        .edge_behaviour = .Dead,
                    }) catch {
                        platform.warn("Could not allocate space for grid clipboard", .{});
                        return;
                    };

                    //self.grid_clipboard.?.copy(dest_rect, self.grid, src_rect);
                },
                else => {},
            },
            .MouseMotion => |ev| {
                if (self.paused and ev.is_pressed(.Left)) setting_cells: {
                    const current_cell = self.cursor_pos_to_cell(ev.pos.intToFloat(f32));
                    if (self.grid_clipboard) |clipboard| {
                        const clipboard_center = clipboard.options.size.scalDiv(2).intCast(i32);
                        const dest = platform.Rect(i32).initPosAndSize(current_cell.sub(clipboard_center), clipboard.options.size.intCast(i32));
                        const src = platform.Rect(i32).initPosAndSize(Vec(2, i32).init(0, 0), clipboard.options.size.intCast(i32));
                        //self.grid.copy(dest, clipboard, src);
                    } else {
                        if (self.start_cell.eql(current_cell)) break :setting_cells;
                        self.fill_line_on_grid(self.prev_cell, current_cell) catch {};
                        self.prev_cell = current_cell;
                    }
                }
                if (ev.is_pressed(.Middle)) panning: {
                    const start_pan = self.start_pan orelse break :panning;
                    const start_camera_pos = self.start_pan_camera_pos orelse break :panning;
                    self.camera_pos = start_pan.sub(ev.pos).intToFloat(f32).add(start_camera_pos);
                }
                self.cursor_pos = ev.pos.intToFloat(f32);
            },
            .MouseWheel => |delta| {
                // Save the position of the cursor in the world
                const cursor_world_pos = self.camera_relative_pos_to_cell(self.cursor_pos_to_camera_relative(self.cursor_pos));

                const deltaY = @intToFloat(f32, delta.y()) * -1;
                self.scale = std.math.clamp(self.scale + deltaY, MIN_SCALE, MAX_SCALE);

                // Set the camera position so that the cursor stays in the same spot in the world
                self.camera_pos = self.cell_pos_to_camera_relative(cursor_world_pos).sub(self.cursor_pos).add(self.screen_size.scalMul(0.5));
            },
            .ScreenResized => |size| {
                self.screen_size = size.intToFloat(f32);
            },
            else => {},
        }
    }

    fn cursor_pos_to_cell(self: *@This(), pos: Vec2f) Vec2i {
        var cell_pos_f = self.camera_relative_pos_to_cell(self.cursor_pos_to_camera_relative(pos));
        cell_pos_f.v[0] = @floor(cell_pos_f.v[0]);
        cell_pos_f.v[1] = @floor(cell_pos_f.v[1]);
        return cell_pos_f.floatToInt(i32);
    }

    fn cursor_pos_to_camera_relative(self: *@This(), pos: Vec2f) Vec2f {
        return pos.sub(self.screen_size.scalMul(0.5)).add(self.camera_pos);
    }

    fn camera_relative_pos_to_cursor(self: *@This(), pos: Vec2f) Vec2f {
        return pos.add(self.screen_size.scalMul(0.5)).sub(self.camera_pos);
    }

    fn camera_relative_pos_to_cell(self: *@This(), pos: Vec2f) Vec2f {
        return pos.scalDiv(self.scale);
    }

    fn cell_pos_to_camera_relative(self: *@This(), pos: Vec2f) Vec2f {
        return pos.scalMul(self.scale);
    }

    fn fill_line_on_grid(self: *@This(), pos0: Vec2i, pos1: Vec2i) !void {
        var p = pos0;
        var d = pos1.sub(pos0);
        d.v[0] = std.math.absInt(d.v[0]) catch return;
        d.v[1] = -(std.math.absInt(d.v[1]) catch return);

        const signs = Vec2i.init(
            if (pos0.x() < pos1.x()) 1 else -1,
            if (pos0.y() < pos1.y()) 1 else -1,
        );
        var err = d.x() + d.y();
        while (true) {
            try self.grid.set(p, true);
            if (p.eql(pos1)) break;
            const e2 = 2 * err;
            if (e2 >= d.y()) {
                err += d.y();
                p.v[0] += signs.x();
            }
            if (e2 <= d.y()) {
                err += d.x();
                p.v[1] += signs.y();
            }
        }
    }

    pub fn update(screenPtr: *Screen, context: *Context, time: f64, delta: f64) ?screen.Transition {
        const self = @fieldParentPtr(@This(), "screen", screenPtr);

        if (self.quit_pressed) {
            self.quit_pressed = false;
        }

        if (!self.paused or self.step_once) {
            if (self.ticks_since_last_step > self.ticks_per_step or self.step_once) {
                self.grid.step() catch |e| {
                    platform.warn("Unable to step grid; {}", .{e});
                };
                self.step_once = false;
                self.ticks_since_last_step = 0;

                // Update generation text label
                context.alloc.free(self.generation_text.text);
                self.generation_text.text = std.fmt.allocPrint(context.alloc, "Generation #{}", .{self.grid.generation}) catch unreachable;
            }
            self.ticks_since_last_step += 1;
        }

        return null;
    }

    pub fn render(screenPtr: *Screen, context: *Context, alpha: f64) void {
        const self = @fieldParentPtr(@This(), "screen", screenPtr);

        context.renderer.begin();

        context.renderer.set_fill_style(.{ .Color = .{ .r = 255, .g = 255, .b = 255, .a = 255 } });
        context.renderer.fill_rect(0, 0, self.screen_size.x(), self.screen_size.y());

        const grid_offset = self.camera_relative_pos_to_cursor(Vec2f.init(0, 0));

        context.renderer.set_stroke_style(.{ .Color = .{ .r = 0xCC, .g = 0xCC, .b = 0xCC, .a = 255 } });
        context.renderer.set_line_cap(.square);
        context.renderer.set_line_width(1.5);

        const quarter = self.scale / 4;
        context.renderer.set_line_dash(&[_]f32{ quarter, 2 * quarter, quarter, 0 });

        const top_left_cell = self.cursor_pos_to_cell(vec2f(0, 0));
        const bottom_right_cell = self.cursor_pos_to_cell(self.screen_size).add(Vec(2, i32).init(1, 1));

        // Render the grid lines
        context.renderer.begin_path();
        var y: i32 = top_left_cell.y();
        while (y <= bottom_right_cell.y()) : (y += 1) {
            context.renderer.move_to(
                grid_offset.x() + @intToFloat(f32, top_left_cell.x()) * self.scale,
                grid_offset.y() + @intToFloat(f32, y) * self.scale,
            );
            context.renderer.line_to(
                grid_offset.x() + @intToFloat(f32, bottom_right_cell.x()) * self.scale,
                grid_offset.y() + @intToFloat(f32, y) * self.scale,
            );
        }
        var x: i32 = top_left_cell.x();
        while (x <= bottom_right_cell.x()) : (x += 1) {
            context.renderer.move_to(
                grid_offset.x() + @intToFloat(f32, x) * self.scale,
                grid_offset.y() + @intToFloat(f32, top_left_cell.y()) * self.scale,
            );
            context.renderer.line_to(
                grid_offset.x() + @intToFloat(f32, x) * self.scale,
                grid_offset.y() + @intToFloat(f32, bottom_right_cell.y()) * self.scale,
            );
        }
        context.renderer.stroke();

        // Render the grid cells
        context.renderer.set_fill_style(.{ .Color = .{ .r = 100, .g = 100, .b = 100, .a = 255 } });

        y = top_left_cell.y();
        while (y <= bottom_right_cell.y() - 1) : (y += 1) {
            x = top_left_cell.x();
            while (x <= bottom_right_cell.x() - 1) : (x += 1) {
                const pos = vec2i(x, y);
                if (self.grid.get(pos)) {
                    const x_epsilon: f32 = if (self.grid.get(pos.add(vec2i(1, 0)))) 1 else 0;
                    const y_epsilon: f32 = if (self.grid.get(pos.add(vec2i(0, 1)))) 1 else 0;
                    context.renderer.fill_rect(
                        grid_offset.x() + @intToFloat(f32, pos.x()) * self.scale,
                        grid_offset.y() + @intToFloat(f32, pos.y()) * self.scale,
                        self.scale + x_epsilon,
                        self.scale + y_epsilon,
                    );
                }
            }
        }

        // Render the clipboard over the other grid
        if (self.grid_clipboard) |clipboard| {
            const clipboard_grid_offset = self.cursor_pos_to_cell(self.cursor_pos);
            const clipboard_offset = self.camera_relative_pos_to_cursor(self.cell_pos_to_camera_relative(clipboard_grid_offset.intToFloat(f32)));
            const clipboard_center = clipboard.options.size.scalDiv(2).intCast(i32);

            // Draw box around clipboard
            context.renderer.set_stroke_style(.{ .Color = .{ .r = 0x11, .g = 0x77, .b = 0x11, .a = 0xAA } });
            context.renderer.set_line_dash(&[_]f32{});
            context.renderer.stroke_rect(
                clipboard_offset.x() - @intToFloat(f32, clipboard_center.x()) * self.scale,
                clipboard_offset.y() - @intToFloat(f32, clipboard_center.y()) * self.scale,
                @intToFloat(f32, clipboard.options.size.x()) * self.scale,
                @intToFloat(f32, clipboard.options.size.y()) * self.scale,
            );

            var clipboard_cell_pos = vec2i(0, 0);
            while (clipboard_cell_pos.y() < clipboard.options.size.y()) : (clipboard_cell_pos.v[1] += 1) {
                clipboard_cell_pos.v[0] = 0;
                while (clipboard_cell_pos.x() < clipboard.options.size.x()) : (clipboard_cell_pos.v[0] += 1) {
                    if (clipboard.get(clipboard_cell_pos.intCast(isize))) {
                        context.renderer.set_fill_style(.{ .Color = .{ .r = 0x77, .g = 0x77, .b = 0x77, .a = 0xAA } });
                        context.renderer.fill_rect(
                            clipboard_offset.x() + @intToFloat(f32, clipboard_cell_pos.x() - clipboard_center.x()) * self.scale,
                            clipboard_offset.y() + @intToFloat(f32, clipboard_cell_pos.y() - clipboard_center.y()) * self.scale,
                            self.scale,
                            self.scale,
                        );
                    } else if (self.grid.get(clipboard_grid_offset.add(clipboard_cell_pos).sub(clipboard_center))) {
                        context.renderer.set_fill_style(.{ .Color = .{ .r = 0x77, .g = 0x11, .b = 0x11, .a = 0xAA } });
                        context.renderer.fill_rect(
                            clipboard_offset.x() + @intToFloat(f32, clipboard_cell_pos.x() - clipboard_center.x()) * self.scale,
                            clipboard_offset.y() + @intToFloat(f32, clipboard_cell_pos.y() - clipboard_center.y()) * self.scale,
                            self.scale,
                            self.scale,
                        );
                    }
                }
            }
        }

        if (self.paused and self.grid_clipboard == null) {
            const highlight_cell_pos = self.cursor_pos_to_cell(self.cursor_pos);
            if (self.grid.get(highlight_cell_pos)) {
                context.renderer.set_fill_style(.{ .Color = .{ .r = 0x77, .g = 0x77, .b = 0x77, .a = 0xFF } });
            } else {
                context.renderer.set_fill_style(.{ .Color = .{ .r = 0xDD, .g = 0xDD, .b = 0xDD, .a = 0xFF } });
            }
            const draw_pos = highlight_cell_pos.intToFloat(f32).scalMul(self.scale).add(grid_offset);
            context.renderer.fill_rect(draw_pos.x(), draw_pos.y(), self.scale, self.scale);
        }
        if (self.paused and self.is_selecting) {
            const current_cell = self.cursor_pos_to_cell(self.cursor_pos);
            const rect = platform.Rect(i32).initTwoPos(self.select_start_cell, current_cell);
            context.renderer.set_fill_style(.{ .Color = .{ .r = 0x77, .g = 0x77, .b = 0x77, .a = 0x77 } });
            context.renderer.fill_rect(
                grid_offset.x() + @intToFloat(f32, rect.min.x()) * self.scale,
                grid_offset.y() + @intToFloat(f32, rect.min.y()) * self.scale,
                @intToFloat(f32, rect.size().x() + 1) * self.scale,
                @intToFloat(f32, rect.size().y() + 1) * self.scale,
            );
        }

        context.renderer.set_fill_style(.{ .Color = .{ .r = 100, .g = 100, .b = 100, .a = 255 } });
        var buf: [100]u8 = undefined;
        {
            const text = std.fmt.bufPrint(&buf, "Ticks Per Step: {d}, Ticks: {d}", .{ self.ticks_per_step, self.ticks_since_last_step }) catch return;
            context.renderer.set_text_align(.Left);
            context.renderer.fill_text(text, 20, self.screen_size.y() - 40);
        }

        self.gui.render(context, alpha);

        context.renderer.flush();
    }

    pub fn deinit(screenPtr: *Screen, context: *Context) void {
        const self = @fieldParentPtr(@This(), "screen", screenPtr);

        self.grid.deinit();
        if (self.grid_clipboard) |clipboard| {
            clipboard.deinit(self.alloc);
        }
        self.gui.deinit();

        self.alloc.destroy(self);
    }
};
