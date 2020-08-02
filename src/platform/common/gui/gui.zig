const std = @import("std");
const platform = @import("../../../platform.zig");

const Allocator = std.mem.Allocator;
const Context = platform.Context;
const Renderer = platform.Renderer;
const Keycode = platform.Keycode;
const Rect = platform.Rect;
const Vec2f = platform.Vec2f;
const vec2f = platform.vec2f;

pub const Label = @import("./label.zig").Label;
pub const Flexbox = @import("./flexbox.zig").Flexbox;
pub const Grid = @import("./grid.zig").Grid;
pub const TextInput = @import("./text_input.zig").TextInput;
pub const Button = @import("./button.zig").Button;
pub const Checkbox = @import("./checkbox.zig").Checkbox;

// A dummy type to use with fieldParentPtr
pub const Props = usize;

pub const Gui = struct {
    alloc: *Allocator,
    renderer: Renderer,
    root: ?*Element,
    cursor_pos: Vec2f,
    focused: ?*Element,

    pub fn init(alloc: *Allocator) @This() {
        return @This(){
            .alloc = alloc,
            .renderer = undefined,
            .root = null,
            .cursor_pos = vec2f(0, 0),
            .focused = null,
        };
    }

    pub fn deinit(self: *@This()) void {
        if (self.root) |root| {
            root.deinit();
        }
    }

    pub fn onEvent(self: *@This(), context: *Context, event: platform.Event) bool {
        const root = self.root orelse return false;
        switch (event) {
            .MouseMotion => |ev| {
                self.cursor_pos = ev.pos.intToFloat(f32);
                return root.onEvent(self, .{ .MouseOver = .{ .pos = self.cursor_pos } });
            },
            .MouseButtonDown => |ev| {
                const consumed = root.onEvent(self, .{ .Click = .{ .pos = self.cursor_pos } });
                if (!consumed) {
                    self.focused = null;
                }
                return consumed;
            },
            .KeyDown => |ev| if (self.focused) |focused| {
                return focused.onEvent(self, .{ .KeyDown = ev.key });
            } else {
                return false;
            },
            .TextInput => |ev| if (self.focused) |focused| {
                return focused.onEvent(self, .{ .TextInput = ev.text });
            } else {
                return false;
            },
            else => return false,
        }
    }

    pub fn render(self: *@This(), context: *Context, alpha: f64) void {
        self.renderer = context.renderer;
        if (self.root) |root| {
            const screen_size = context.getScreenSize().intToFloat(f32);
            const rect = Rect(f32).initPosAndSize(vec2f(0, 0), screen_size);
            root.render(self, rect, alpha);
        }
    }
};

pub const Element = struct {
    // Returns true if the event has been consumed
    deinitFn: fn (*Element) void,
    onEventFn: fn (*Element, *Gui, Event) bool,
    minimumSizeFn: fn (*Element, *Gui) Vec2f,
    renderFn: fn (*Element, *Gui, Rect(f32), alpha: f64) void,

    margin: Extents = .{},

    pub fn deinit(self: *@This()) void {
        self.deinitFn(self);
    }

    pub fn onEvent(self: *@This(), gui: *Gui, event: Event) bool {
        return self.onEventFn(self, gui, event);
    }

    pub fn minimumSize(self: *@This(), gui: *Gui) Vec2f {
        const size = self.minimumSizeFn(self, gui);

        return size.add(vec2f(
            self.margin.left + self.margin.right,
            self.margin.top + self.margin.bottom,
        ));
    }

    pub fn render(self: *@This(), gui: *Gui, rect: Rect(f32), alpha: f64) void {
        const min = rect.min.add(vec2f(self.margin.left, self.margin.top));
        const max = rect.max.sub(vec2f(self.margin.right, self.margin.bottom));

        if (min.x() > max.x() or min.y() > max.y()) {
            // TODO: Log something?
            return;
        }

        self.renderFn(self, gui, Rect(f32).initMinAndMax(min, max), alpha);
    }
};

pub const Extents = struct {
    top: f32 = 0,
    bottom: f32 = 0,
    left: f32 = 0,
    right: f32 = 0,

    pub fn tb_lr(tb: f32, lr: f32) @This() {
        return .{
            .top = tb,
            .bottom = tb,
            .left = lr,
            .right = lr,
        };
    }

    pub fn tblr(tblr: f32) @This() {
        return .{
            .top = tblr,
            .bottom = tblr,
            .left = tblr,
            .right = tblr,
        };
    }
};

pub const Event = union(enum) {
    MouseOver: MouseEvent,
    MouseEnter: MouseEvent,
    MouseLeave: MouseEvent,
    Click: MouseEvent,
    KeyDown: Keycode,
    TextInput: []const u8,
};

pub const MouseEvent = struct {
    pos: Vec2f,
};
