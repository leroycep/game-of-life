const std = @import("std");
const seizer = @import("seizer");
const gui = @import("./gui/gui.zig");

const Vec = seizer.math.Vec;
const Vec2f = Vec(2, f32);
const vec2f = Vec(2, f32).init;
const Vec2i = Vec(2, i32);
const vec2i = Vec(2, i32).init;
const vec2us = Vec(2, usize).init;
const Rect = @import("./rect.zig").Rect;

const game = @import("./game.zig");
const World = game.World;
const GridOfLife = game.GridOfLife;
const constants = @import("../constants.zig");
const canvas = @import("canvas");

const DEFAULT_GRID_WIDTH = 100;
const DEFAULT_GRID_HEIGHT = 100;
const CELL_WIDTH = 16;
const CELL_HEIGHT = 16;
const MIN_SCALE = 2;
const MAX_SCALE = 1024;

const TEXT_PRESS_RIGHT = "Press → to advance one step";

pub const Game = struct {
    alloc: *std.mem.Allocator,

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

    pub fn init(alloc: *std.mem.Allocator) !@This() {
        var grid = try World.init(alloc);
        errdefer grid.deinit();
        const grid_clipboard = try GridOfLife.init(alloc, .{
            .size = vec2us(0, 0),
            .edge_behaviour = .Dead,
        });
        errdefer grid_clipboard.deinit(alloc);
        return @This(){
            .alloc = alloc,
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
    }

    pub fn start(self: *@This()) void {
        self.screen_size = seizer.getScreenSize().intToFloat(f32);

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
        fullscreen_button.userdata = @ptrToInt(self);

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
        //context.request_fullscreen();
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
                std.log.warn("Could not allocate space for new grid", .{});
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

    pub fn onEvent(self: *@This(), event: seizer.event.Event) void {
        if (self.gui.onEvent(event)) {
            // The event has been consumed by the UI
            return;
        }
        switch (event) {
            .Quit => seizer.quit(),
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
                        const clipboard_center = clipboard.options.size.scaleDiv(2).intCast(i32);
                        const dest = self.start_cell.subv(clipboard_center);
                        clipboard.paste(&self.grid, dest) catch |e| {
                            std.log.warn("Failed to paste clipboard to grid, {}", .{e});
                        };
                    } else {
                        self.grid.set(self.start_cell, !self.grid.get(self.start_cell)) catch unreachable;
                    }
                },
                .Middle => {
                    self.start_pan = ev.pos;
                    self.start_pan_camera_pos = self.camera_pos;
                    // TODO: reimplement set_cursor
                    //context.set_cursor(.grabbing);
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
                    // TODO: reimplement set_cursor
                    // context.set_cursor(.default);
                },
                .Right => {
                    self.is_selecting = false;
                    // TODO: reimplement set_cursor
                    // context.set_cursor(.default);

                    if (!self.paused) {
                        // Don't copy the grid while the simulation is running, only allow emptying the clipboard
                        return;
                    }

                    // Copy selection to grid clipboard
                    const end_cell = self.cursor_pos_to_cell(ev.pos.intToFloat(f32));
                    var src_rect = Rect(i32).initTwoPos(self.select_start_cell, end_cell);
                    src_rect.max = src_rect.max.add(1, 1);

                    if (src_rect.size().x <= 1 and src_rect.size().y <= 1) {
                        // Only one cell in the selection, don't copy it
                        return;
                    }

                    self.grid_clipboard = GridOfLife.copy(self.alloc, self.grid, src_rect) catch |e| {
                        std.log.warn("Could not allocate space for grid clipboard, {}", .{e});
                        return;
                    };
                },
                else => {},
            },
            .MouseMotion => |ev| {
                if (self.paused and ev.is_pressed(.Left)) setting_cells: {
                    const current_cell = self.cursor_pos_to_cell(ev.pos.intToFloat(f32));
                    if (self.grid_clipboard) |clipboard| {
                        const clipboard_center = clipboard.options.size.scaleDiv(2).intCast(i32);
                        const dest = current_cell.subv(clipboard_center);
                        clipboard.paste(&self.grid, dest) catch |e| {
                            std.log.warn("Failed to paste clipboard to grid, {}", .{e});
                        };
                    } else {
                        if (self.start_cell.eql(current_cell)) break :setting_cells;
                        self.fill_line_on_grid(self.prev_cell, current_cell) catch {};
                        self.prev_cell = current_cell;
                    }
                }
                //std.log.debug("mouse motion buttons = {}", .{ev.buttons});
                if (ev.is_pressed(.Middle)) panning: {
                    const start_pan = self.start_pan orelse break :panning;
                    const start_camera_pos = self.start_pan_camera_pos orelse break :panning;
                    self.camera_pos = start_pan.subv(ev.pos).intToFloat(f32).addv(start_camera_pos);
                }
                self.cursor_pos = ev.pos.intToFloat(f32);
            },
            .MouseWheel => |delta| {
                // Save the position of the cursor in the world
                const cursor_world_pos = self.camera_relative_pos_to_cell(self.cursor_pos_to_camera_relative(self.cursor_pos));

                const deltaY = @intToFloat(f32, delta.y) * -1;
                self.scale = std.math.clamp(self.scale + deltaY, MIN_SCALE, MAX_SCALE);

                // Set the camera position so that the cursor stays in the same spot in the world
                self.camera_pos = self.cell_pos_to_camera_relative(cursor_world_pos).subv(self.cursor_pos).addv(self.screen_size.scale(0.5));
            },
            .ScreenResized => |size| {
                self.screen_size = size.intToFloat(f32);
            },
            else => {},
        }
    }

    fn cursor_pos_to_cell(self: *@This(), pos: Vec2f) Vec2i {
        var cell_pos_f = self.camera_relative_pos_to_cell(self.cursor_pos_to_camera_relative(pos));
        cell_pos_f.x = @floor(cell_pos_f.x);
        cell_pos_f.y = @floor(cell_pos_f.y);
        return cell_pos_f.floatToInt(i32);
    }

    fn cursor_pos_to_camera_relative(self: *@This(), pos: Vec2f) Vec2f {
        return pos.subv(self.screen_size.scale(0.5)).addv(self.camera_pos);
    }

    fn camera_relative_pos_to_cursor(self: *@This(), pos: Vec2f) Vec2f {
        return pos.addv(self.screen_size.scale(0.5)).subv(self.camera_pos);
    }

    fn camera_relative_pos_to_cell(self: *@This(), pos: Vec2f) Vec2f {
        return pos.scaleDiv(self.scale);
    }

    fn cell_pos_to_camera_relative(self: *@This(), pos: Vec2f) Vec2f {
        return pos.scale(self.scale);
    }

    fn fill_line_on_grid(self: *@This(), pos0: Vec2i, pos1: Vec2i) !void {
        var p = pos0;
        var d = pos1.subv(pos0);
        d.x = std.math.absInt(d.x) catch return;
        d.y = -(std.math.absInt(d.y) catch return);

        const signs = Vec2i.init(
            if (pos0.x < pos1.x) 1 else -1,
            if (pos0.y < pos1.y) 1 else -1,
        );
        var err = d.x + d.y;
        while (true) {
            try self.grid.set(p, true);
            if (p.eql(pos1)) break;
            const e2 = 2 * err;
            if (e2 >= d.y) {
                err += d.y;
                p.x += signs.x;
            }
            if (e2 <= d.y) {
                err += d.x;
                p.y += signs.y;
            }
        }
    }

    pub fn update(self: *@This(), time: f64, delta: f64) void {
        if (self.quit_pressed) {
            self.quit_pressed = false;
        }

        if (!self.paused or self.step_once) {
            if (self.ticks_since_last_step > self.ticks_per_step or self.step_once) {
                self.grid.step() catch |e| {
                    std.log.warn("Unable to step grid; {}", .{e});
                    self.paused = true;
                };
                self.step_once = false;
                self.ticks_since_last_step = 0;

                // Update generation text label
                self.alloc.free(self.generation_text.text);
                self.generation_text.text = std.fmt.allocPrint(self.alloc, "Generation #{}", .{self.grid.generation}) catch unreachable;
            }
            self.ticks_since_last_step += 1;
        }
    }

    pub fn render(self: *@This(), alpha: f64) void {
        canvas.begin();

        canvas.set_fill_style(.{ .Color = .{ .r = 255, .g = 255, .b = 255, .a = 255 } });
        canvas.fill_rect(0, 0, self.screen_size.x, self.screen_size.y);

        const grid_offset = self.camera_relative_pos_to_cursor(Vec2f.init(0, 0));

        const cell_rect = Rect(i32).initMinAndMax(
            self.cursor_pos_to_cell(vec2f(0, 0)),
            self.cursor_pos_to_cell(self.screen_size).add(1, 1),
        );

        self.grid.render(cell_rect, grid_offset, self.scale);

        // Render the clipboard over the other grid
        if (self.grid_clipboard) |clipboard| {
            const clipboard_grid_offset = self.cursor_pos_to_cell(self.cursor_pos);
            const clipboard_offset = self.camera_relative_pos_to_cursor(self.cell_pos_to_camera_relative(clipboard_grid_offset.intToFloat(f32)));
            const clipboard_center = clipboard.options.size.scaleDiv(2).intCast(i32);

            // Draw box around clipboard
            canvas.set_stroke_style(.{ .Color = .{ .r = 0x11, .g = 0x77, .b = 0x11, .a = 0xAA } });
            canvas.set_line_dash(&[_]f32{});
            canvas.stroke_rect(
                clipboard_offset.x - @intToFloat(f32, clipboard_center.x) * self.scale,
                clipboard_offset.y - @intToFloat(f32, clipboard_center.y) * self.scale,
                @intToFloat(f32, clipboard.options.size.x) * self.scale,
                @intToFloat(f32, clipboard.options.size.y) * self.scale,
            );

            var clipboard_cell_pos = vec2i(0, 0);
            while (clipboard_cell_pos.y < clipboard.options.size.y) : (clipboard_cell_pos.y += 1) {
                clipboard_cell_pos.x = 0;
                while (clipboard_cell_pos.x < clipboard.options.size.x) : (clipboard_cell_pos.x += 1) {
                    if (clipboard.get(clipboard_cell_pos.intCast(isize))) {
                        canvas.set_fill_style(.{ .Color = .{ .r = 0x77, .g = 0x77, .b = 0x77, .a = 0xAA } });
                        canvas.fill_rect(
                            clipboard_offset.x + @intToFloat(f32, clipboard_cell_pos.x - clipboard_center.x) * self.scale,
                            clipboard_offset.y + @intToFloat(f32, clipboard_cell_pos.y - clipboard_center.y) * self.scale,
                            self.scale,
                            self.scale,
                        );
                    } else if (self.grid.get(clipboard_grid_offset.addv(clipboard_cell_pos).subv(clipboard_center))) {
                        canvas.set_fill_style(.{ .Color = .{ .r = 0x77, .g = 0x11, .b = 0x11, .a = 0xAA } });
                        canvas.fill_rect(
                            clipboard_offset.x + @intToFloat(f32, clipboard_cell_pos.x - clipboard_center.x) * self.scale,
                            clipboard_offset.y + @intToFloat(f32, clipboard_cell_pos.y - clipboard_center.y) * self.scale,
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
                canvas.set_fill_style(.{ .Color = .{ .r = 0x77, .g = 0x77, .b = 0x77, .a = 0xFF } });
            } else {
                canvas.set_fill_style(.{ .Color = .{ .r = 0xDD, .g = 0xDD, .b = 0xDD, .a = 0xFF } });
            }
            const draw_pos = highlight_cell_pos.intToFloat(f32).scale(self.scale).addv(grid_offset);
            canvas.fill_rect(draw_pos.x, draw_pos.y, self.scale, self.scale);
        }
        if (self.paused and self.is_selecting) {
            const current_cell = self.cursor_pos_to_cell(self.cursor_pos);
            const rect = Rect(i32).initTwoPos(self.select_start_cell, current_cell);
            canvas.set_fill_style(.{ .Color = .{ .r = 0x77, .g = 0x77, .b = 0x77, .a = 0x77 } });
            canvas.fill_rect(
                grid_offset.x + @intToFloat(f32, rect.min.x) * self.scale,
                grid_offset.y + @intToFloat(f32, rect.min.y) * self.scale,
                @intToFloat(f32, rect.size().x + 1) * self.scale,
                @intToFloat(f32, rect.size().y + 1) * self.scale,
            );
        }

        canvas.set_fill_style(.{ .Color = .{ .r = 100, .g = 100, .b = 100, .a = 255 } });
        var buf: [100]u8 = undefined;
        {
            const text = std.fmt.bufPrint(&buf, "Ticks Per Step: {d}, Ticks: {d}", .{ self.ticks_per_step, self.ticks_since_last_step }) catch return;
            canvas.set_text_align(.Left);
            canvas.fill_text(text, 20, self.screen_size.y - 40);
        }

        self.gui.render(alpha);

        canvas.flush();
    }

    pub fn deinit(self: *@This()) void {
        self.grid.deinit();
        if (self.grid_clipboard) |clipboard| {
            clipboard.deinit(self.alloc);
        }
        self.gui.deinit();

        self.alloc.destroy(self);
    }
};
