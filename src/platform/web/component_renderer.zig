const std = @import("std");
const components = @import("../components.zig");
const Component = components.Component;
const ComponentTag = components.ComponentTag;
const Layout = components.Layout;
const Events = components.Events;

pub const TAG_DIV: u32 = 1;
pub const TAG_P: u32 = 2;
pub const TAG_BUTTON: u32 = 3;

pub const CLASS_HORIZONTAL: u32 = 1;
pub const CLASS_VERTICAL: u32 = 2;
pub const CLASS_FLEX: u32 = 3;
pub const CLASS_GRID: u32 = 4;

pub const CLASS_FLEX_MAIN_START: u32 = 5;
pub const CLASS_FLEX_MAIN_CENTER: u32 = 6;
pub const CLASS_FLEX_MAIN_END: u32 = 7;
pub const CLASS_FLEX_MAIN_SPACE_BETWEEN: u32 = 8;
pub const CLASS_FLEX_MAIN_SPACE_AROUND: u32 = 9;
pub const CLASS_FLEX_CROSS_START: u32 = 10;
pub const CLASS_FLEX_CROSS_CENTER: u32 = 11;
pub const CLASS_FLEX_CROSS_END: u32 = 12;

pub extern fn element_create(tag: u32) u32;
pub extern fn element_remove(element: u32) void;
pub extern fn element_setTextS(element: u32, textPtr: [*]const u8, textLen: c_uint) void;

pub extern fn element_setClickEvent(element: u32, clickEvent: u32) void;
pub extern fn element_removeClickEvent(element: u32) void;
pub extern fn element_setHoverEvent(element: u32, hoverEvent: u32) void;
pub extern fn element_removeHoverEvent(element: u32) void;

pub extern fn element_addClass(element: u32, class: u32) void;
pub extern fn element_clearClasses(element: u32) void;
pub extern fn element_appendChild(element: u32, child: u32) void;
pub extern fn element_setGridArea(element: u32, grid_area: u32) void;
pub extern fn element_setGridTemplateAreasS(element: u32, grid_areas: [*]const u32, width: u32, height: u32) void;
pub extern fn element_setGridTemplateRowsS(element: u32, cols: [*]const u32, len: u32) void;
pub extern fn element_setGridTemplateColumnsS(element: u32, rows: [*]const u32, len: u32) void;

/// Returns the root element
pub extern fn element_render_begin() u32;

/// Called to clean up data on JS side
pub extern fn element_render_clear() void;

pub fn element_setText(element: u32, text: []const u8) void {
    element_setTextS(element, text.ptr, text.len);
}

pub fn element_setGridTemplateRows(element: u32, cols: []const u32) void {
    element_setGridTemplateRowsS(element, cols.ptr, cols.len);
}
pub fn element_setGridTemplateColumns(element: u32, rows: []const u32) void {
    element_setGridTemplateColumnsS(element, rows.ptr, rows.len);
}

pub fn element_setGridTemplateAreas(element: u32, grid_areas: []const []const usize) void {
    const ARBITRARY_BUFFER_SIZE = 1024;
    const width = grid_areas[0].len;
    const height = grid_areas.len;
    var areas: [ARBITRARY_BUFFER_SIZE]usize = undefined;
    for (grid_areas) |row, y| {
        for (row) |area, x| {
            areas[y * width + x] = area;
        }
    }
    element_setGridTemplateAreasS(element, &areas, width, height);
}

pub const ComponentRenderer = struct {
    alloc: *std.mem.Allocator,
    root_element: ?u32 = null,
    current_component: ?RenderedComponent = null,

    pub fn init(alloc: *std.mem.Allocator) !@This() {
        return @This(){
            .alloc = alloc,
        };
    }

    pub fn update(self: *@This(), new_component: *const Component) !void {
        if (self.current_component) |*current_component| {
            try current_component.differences(new_component);
        } else {
            const rootElement = element_render_begin();
            self.current_component = try componentToRendered(self.alloc, new_component);
            element_appendChild(rootElement, self.current_component.?.element);
        }
    }

    pub fn clear(self: *@This()) void {
        element_render_clear();
        self.current_component = null;
    }
};

const RenderedComponent = struct {
    alloc: *std.mem.Allocator,
    element: u32,
    component: union(ComponentTag) {
        Text: []const u8,
        Button: Button,
        Container: Container,

        pub fn deinit(self: *@This(), component: *RenderedComponent) void {
            switch (self.*) {
                .Text => |text| component.alloc.free(text),
                .Button => |button| component.alloc.free(button.text),
                .Container => |*container| container.deinit(component),
            }
        }
    },

    pub fn remove(self: *@This()) void {
        element_remove(self.element);
        self.component.deinit(self);
    }

    pub fn deinit(self: *@This()) void {
        self.component.deinit(self);
    }

    pub fn differences(self: *@This(), other: *const Component) RenderingError!void {
        if (@as(ComponentTag, self.component) != @as(ComponentTag, other.*)) {
            self.remove();
            self.* = try componentToRendered(self.alloc, other);
            return;
        }
        // Tags must be equal
        switch (self.component) {
            .Text => |self_text| {
                if (!std.mem.eql(u8, self_text, other.Text)) {
                    element_setText(self.element, other.Text);
                }
            },

            .Button => |*self_button| {
                if (!std.mem.eql(u8, self_button.text, other.Button.text)) {
                    element_setText(self.element, other.Button.text);
                }

                if (!std.meta.eql(self_button.events, other.Button.events)) {
                    self_button.update_events(self, other.Button.events);
                }
            },

            .Container => |*self_container| {
                if (!std.meta.eql(self_container.layout, other.Container.layout)) {
                    element_clearClasses(self.element);
                    apply_layout(self.element, &other.Container.layout);
                }
                var changed = other.Container.children.len != self_container.children.items.len;
                var idx: usize = 0;
                while (!changed and idx < other.Container.children.len) : (idx += 1) {
                    const self_child = &self_container.children.span()[idx];
                    const other_child = &other.Container.children[idx];
                    if (@as(ComponentTag, self_child.component) == @as(ComponentTag, other_child.*)) {
                        try self_child.differences(other_child);
                    } else {
                        changed = true;
                    }
                }

                if (changed) {
                    // Clear children and rebuild
                    self_container.removeChildren();
                    for (other.Container.children) |*other_child, childIdx| {
                        const childElem = try componentToRendered(self.alloc, other_child);
                        element_appendChild(self.element, childElem.element);
                        self_container.children.append(childElem) catch unreachable;

                        if (other.Container.layout == .Grid and other.Container.layout.Grid.areas != null) {
                            element_setGridArea(childElem.element, childIdx);
                        }
                    }
                }
            },
        }
    }
};

const Button = struct {
    text: []const u8,
    events: Events,

    pub fn update_events(self: *@This(), component: *const RenderedComponent, new_events: Events) void {
        if (new_events.click) |new_click| {
            element_setClickEvent(component.element, new_click);
        } else if (self.events.click) |old_click| {
            element_removeClickEvent(component.element);
        }
        self.events.click = new_events.click;

        if (new_events.hover) |new_hover| {
            element_setHoverEvent(component.element, new_hover);
        } else if (self.events.hover) |old_hover| {
            element_removeHoverEvent(component.element);
        }
        self.events.hover = new_events.hover;
    }
};

pub const Container = struct {
    layout: Layout,
    children: std.ArrayList(RenderedComponent),

    pub fn removeChildren(self: *@This()) void {
        for (self.children.span()) |*child| {
            child.remove();
        }
        self.children.resize(0) catch unreachable;
    }

    pub fn deinit(self: *@This(), component: *RenderedComponent) void {
        for (self.children.span()) |*child| {
            child.deinit();
        }
        self.children.deinit();
    }
};

pub const RenderingError = std.mem.Allocator.Error;

pub fn componentToRendered(alloc: *std.mem.Allocator, component: *const Component) RenderingError!RenderedComponent {
    switch (component.*) {
        .Text => |text| {
            const elem = element_create(TAG_P);
            element_setText(elem, text);
            return RenderedComponent{
                .alloc = alloc,
                .element = elem,
                .component = .{
                    .Text = try std.mem.dupe(alloc, u8, text),
                },
            };
        },
        .Button => |button| {
            const elem = element_create(TAG_BUTTON);
            element_setText(elem, button.text);
            if (button.events.click) |click_event| {
                element_setClickEvent(elem, click_event);
            }
            if (button.events.hover) |hover_event| {
                element_setHoverEvent(elem, hover_event);
            }
            return RenderedComponent{
                .alloc = alloc,
                .element = elem,
                .component = .{
                    .Button = .{
                        .text = try std.mem.dupe(alloc, u8, button.text),
                        .events = button.events,
                    },
                },
            };
        },
        .Container => |container| {
            const elem = element_create(TAG_DIV);

            // Add some classes to the div
            apply_layout(elem, &container.layout);

            var rendered_children = std.ArrayList(RenderedComponent).init(alloc);
            for (container.children) |*child, idx| {
                const childElem = try componentToRendered(alloc, child);
                element_appendChild(elem, childElem.element);
                try rendered_children.append(childElem);

                if (container.layout == .Grid and container.layout.Grid.areas != null) {
                    element_setGridArea(childElem.element, idx);
                }
            }

            return RenderedComponent{
                .alloc = alloc,
                .element = elem,
                .component = .{
                    .Container = .{
                        .layout = container.layout,
                        .children = rendered_children,
                    },
                },
            };
        },
    }
}

pub fn apply_layout(element: u32, layout: *const Layout) void {
    switch (layout.*) {
        .Flex => |flex| {
            element_addClass(element, CLASS_FLEX);
            element_addClass(element, switch (flex.orientation) {
                .Horizontal => CLASS_HORIZONTAL,
                .Vertical => CLASS_VERTICAL,
            });
            element_addClass(element, switch (flex.main_axis_alignment) {
                .Start => CLASS_FLEX_MAIN_START,
                .Center => CLASS_FLEX_MAIN_CENTER,
                .End => CLASS_FLEX_MAIN_END,
                .SpaceBetween => CLASS_FLEX_MAIN_SPACE_BETWEEN,
                .SpaceAround => CLASS_FLEX_MAIN_SPACE_AROUND,
            });
            element_addClass(element, switch (flex.cross_axis_alignment) {
                .Start => CLASS_FLEX_CROSS_START,
                .Center => CLASS_FLEX_CROSS_CENTER,
                .End => CLASS_FLEX_CROSS_END,
            });
        },
        .Grid => |template| {
            element_addClass(element, CLASS_GRID);
            if (template.areas) |areas| {
                element_setGridTemplateAreas(element, areas);
            }
            if (template.column) |rows| {
                element_setGridTemplateRows(element, rows);
            }
            if (template.row) |cols| {
                element_setGridTemplateColumns(element, cols);
            }
        },
    }
}
