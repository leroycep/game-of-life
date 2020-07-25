const std = @import("std");

const Func = struct {
    name: []const u8,
    args: []const Arg,
    ret: []const u8,
    js: []const u8,
};

const Arg = struct {
    name: []const u8,
    type: []const u8,
};

const zig_top = "";

// memory has to be wrapped in a getter because we need the "env" before we can
// even get the memory
const js_top =
    \\export default function getWebGLEnv(canvas_element, getMemory) {
    \\    const readCharStr = (ptr, len) => {
    \\        const bytes = new Uint8Array(getMemory().buffer, ptr, len);
    \\        let s = "";
    \\        for (let i = 0; i < len; ++i) {
    \\            s += String.fromCharCode(bytes[i]);
    \\        }
    \\        return s;
    \\    };
    \\    const writeCharStr = (ptr, len, lenRetPtr, text) => {
    \\        const encoder = new TextEncoder();
    \\        const message = encoder.encode(text);
    \\        const zigbytes = new Uint8Array(getMemory().buffer, ptr, len);
    \\        let zigidx = 0;
    \\        for (const b of message) {
    \\            if (zigidx >= len-1) break;
    \\            zigbytes[zigidx] = b;
    \\            zigidx += 1;
    \\        }
    \\        zigbytes[zigidx] = 0;
    \\        if (lenRetPtr !== 0) {
    \\            new Uint32Array(getMemory().buffer, lenRetPtr, 1)[0] = zigidx;
    \\        }
    \\    }
    \\
    \\    const canvas = canvas_element.getContext('2d');
    \\
    \\    const textAlignMap = ["left", "right", "center"];
;

const js_bottom =
    \\}
;

const funcs = [_]Func{
    Func{
        .name = "getScreenW",
        .args = &[_]Arg{},
        .ret = "i32",
        .js =
            \\return canvas_element.getBoundingClientRect().width;
            },
    Func{
        .name = "getScreenH",
        .args = &[_]Arg{},
        .ret = "i32",
        .js =
            \\return canvas_element.getBoundingClientRect().height;
            },
    Func{
        .name = "canvas_clearRect",
        .args = &[_]Arg{
            .{ .name = "x", .type = "f32" },
            .{ .name = "y", .type = "f32" },
            .{ .name = "width", .type = "f32" },
            .{ .name = "height", .type = "f32" },
        },
        .ret = "void",
        .js =
            \\canvas.clearRect(x,y,width,height);
            },
    Func{
        .name = "canvas_fillRect",
        .args = &[_]Arg{
            .{ .name = "x", .type = "f32" },
            .{ .name = "y", .type = "f32" },
            .{ .name = "width", .type = "f32" },
            .{ .name = "height", .type = "f32" },
        },
        .ret = "void",
        .js =
            \\canvas.fillRect(x,y,width,height);
            },
    Func{
        .name = "canvas_setFillStyle_rgba",
        .args = &[_]Arg{
            .{ .name = "r", .type = "u8" },
            .{ .name = "g", .type = "u8" },
            .{ .name = "b", .type = "u8" },
            .{ .name = "a", .type = "u8" },
        },
        .ret = "void",
        .js =
            \\canvas.fillStyle = `rgba(${r},${g},${b},${a})`;
            },
    Func{
        .name = "canvas_setTextAlign",
        .args = &[_]Arg{
            .{ .name = "text_align", .type = "u8" },
        },
        .ret = "void",
        .js =
            \\canvas.textAlign = textAlignMap[text_align];
            },
    Func{
        .name = "canvas_fillText",
        .args = &[_]Arg{
            .{ .name = "text", .type = "SLICE" },
            .{ .name = "x", .type = "f32" },
            .{ .name = "y", .type = "f32" },
        },
        .ret = "void",
        .js =
            \\canvas.fillText(text, x, y);
            },
};

fn nextNewline(s: []const u8) usize {
    for (s) |ch, i| {
        if (ch == '\n') {
            return i;
        }
    }
    return s.len;
}

fn writeZigFile(filename: []const u8) !void {
    const file = try std.fs.cwd().createFile(filename, .{});
    defer file.close();

    var stream = file.outStream();

    try stream.print("{}\n\n", .{zig_top});

    for (funcs) |func| {
        const any_slice = for (func.args) |arg| {
            if (std.mem.eql(u8, arg.type, "SLICE")) {
                break true;
            }
        } else false;

        // https://github.com/ziglang/zig/issues/3882
        const fmtarg_pub = if (any_slice) "" else "pub ";
        const fmtarg_suf = if (any_slice) "_" else "";
        try stream.print("{}extern fn {}{}(", .{ fmtarg_pub, func.name, fmtarg_suf });
        for (func.args) |arg, i| {
            if (i > 0) {
                try stream.print(", ", .{});
            }
            if (std.mem.eql(u8, arg.type, "SLICE")) {
                try stream.print("{}_ptr: [*]const u8, {}_len: c_uint", .{ arg.name, arg.name });
            } else {
                try stream.print("{}: {}", .{ arg.name, arg.type });
            }
        }
        try stream.print(") {};\n", .{func.ret});

        if (any_slice) {
            try stream.print("pub fn {}(", .{func.name});
            for (func.args) |arg, i| {
                if (i > 0) {
                    try stream.print(", ", .{});
                }
                if (std.mem.eql(u8, arg.type, "SLICE")) {
                    try stream.print("{}: []const u8", .{arg.name});
                } else {
                    try stream.print("{}: {}", .{ arg.name, arg.type });
                }
            }
            try stream.print(") {} {{\n", .{func.ret});
            // https://github.com/ziglang/zig/issues/3882
            const fmtarg_ret = if (std.mem.eql(u8, func.ret, "void")) "" else "return ";
            try stream.print("    {}{}_(", .{ fmtarg_ret, func.name });
            for (func.args) |arg, i| {
                if (i > 0) {
                    try stream.print(", ", .{});
                }
                if (std.mem.eql(u8, arg.type, "SLICE")) {
                    try stream.print("{}.ptr, {}.len", .{ arg.name, arg.name });
                } else {
                    try stream.print("{}", .{arg.name});
                }
            }
            try stream.print(");\n", .{});
            try stream.print("}}\n", .{});
        }
    }
}

fn writeJsFile(filename: []const u8) !void {
    const file = try std.fs.cwd().createFile(filename, .{});
    defer file.close();

    var stream = file.outStream();

    try stream.print("{}\n", .{js_top});

    try stream.print("    return {{\n", .{});
    for (funcs) |func| {
        const any_slice = for (func.args) |arg| {
            if (std.mem.eql(u8, arg.type, "SLICE")) {
                break true;
            }
        } else false;

        // https://github.com/ziglang/zig/issues/3882
        const fmtarg_suf = if (any_slice) "_" else "";
        try stream.print("        {}{}(", .{ func.name, fmtarg_suf });
        for (func.args) |arg, i| {
            if (i > 0) {
                try stream.print(", ", .{});
            }
            if (std.mem.eql(u8, arg.type, "SLICE")) {
                try stream.print("{}_ptr, {}_len", .{ arg.name, arg.name });
            } else {
                try stream.print("{}", .{arg.name});
            }
        }
        try stream.print(") {{\n", .{});
        for (func.args) |arg| {
            if (std.mem.eql(u8, arg.type, "SLICE")) {
                try stream.print("            const {} = readCharStr({}_ptr, {}_len);\n", .{ arg.name, arg.name, arg.name });
            }
        }
        var start: usize = 0;
        while (start < func.js.len) {
            const rel_newline_pos = nextNewline(func.js[start..]);
            try stream.print("            {}\n", .{func.js[start .. start + rel_newline_pos]});
            start += rel_newline_pos + 1;
        }
        try stream.print("        }},\n", .{});
    }
    try stream.print("    }};\n", .{});

    try stream.print("{}\n", .{js_bottom});
}

pub fn main() !void {
    try writeZigFile("src/platform/web_canvas_generated.zig");
    try writeJsFile("js/canvas_generated.js");
}
