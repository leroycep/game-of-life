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
    \\export default function getWebGLEnv(canvas_element, getInstance) {
    \\    const getMemory = () => getInstance().exports.memory;
    \\    const utf8decoder = new TextDecoder();
    \\    const readCharStr = (ptr, len) =>
    \\        utf8decoder.decode(new Uint8Array(getMemory().buffer, ptr, len));
    \\    const readF32Array = (ptr, len) =>
    \\        new Float32Array(getMemory().buffer, ptr, len);
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
    \\    const readU32Const = (ptr) => new Uint32Array(getMemory().buffer, ptr, 1)[0];
    \\
    \\    let wasmTextMetricsMap;
    \\    const getWasmTextMetricsMap = () => {
    \\        if (wasmTextMetricsMap) return wasmTextMetricsMap;
    \\        wasmTextMetricsMap = {
    \\            _size: readU32Const(getInstance().exports.TextMetrics_SIZE),
    \\            width: readU32Const(getInstance().exports.TextMetrics_OFFSET_width),
    \\            actualBoundingBoxAscent: readU32Const(getInstance().exports.TextMetrics_OFFSET_actualBoundingBoxAscent),
    \\            actualBoundingBoxDescent: readU32Const(getInstance().exports.TextMetrics_OFFSET_actualBoundingBoxDescent),
    \\            actualBoundingBoxLeft: readU32Const(getInstance().exports.TextMetrics_OFFSET_actualBoundingBoxLeft),
    \\            actualBoundingBoxRight: readU32Const(getInstance().exports.TextMetrics_OFFSET_actualBoundingBoxRight),
    \\        }
    \\        return wasmTextMetricsMap;
    \\    };
    \\
    \\    const canvas = canvas_element.getContext('2d');
    \\
    \\    const textAlignMap = ["left", "right", "center"];
    \\    const textBaselineMap = ["top", "hanging", "middle", "alphabetic", "ideographic", "bottom"];
    \\    const lineCapMap = ["butt", "round", "square"];
    \\    const cursorStyleMap = ["default", "move", "grabbing"];
;

const js_bottom =
    \\}
;

pub const extern_name = "canvas";

const funcs = [_]Func{
    Func{ .name = "getScreenW", .args = &[_]Arg{}, .ret = "i32", .js = 
    \\return element.getBoundingClientRect().width;
    },
    Func{ .name = "getScreenH", .args = &[_]Arg{}, .ret = "i32", .js = 
    \\return element.getBoundingClientRect().height;
    },
    Func{ .name = "setCursorStyle", .args = &[_]Arg{
        .{ .name = "style", .type = "u32" },
    }, .ret = "void", .js = 
    \\element.style.cursor = cursorStyleMap[style];
    },
    Func{ .name = "clearRect", .args = &[_]Arg{
        .{ .name = "x", .type = "f32" },
        .{ .name = "y", .type = "f32" },
        .{ .name = "width", .type = "f32" },
        .{ .name = "height", .type = "f32" },
    }, .ret = "void", .js = 
    \\canvas.clearRect(x,y,width,height);
    },
    Func{ .name = "fillRect", .args = &[_]Arg{
        .{ .name = "x", .type = "f32" },
        .{ .name = "y", .type = "f32" },
        .{ .name = "width", .type = "f32" },
        .{ .name = "height", .type = "f32" },
    }, .ret = "void", .js = 
    \\canvas.fillRect(x,y,width,height);
    },
    Func{ .name = "strokeRect", .args = &[_]Arg{
        .{ .name = "x", .type = "f32" },
        .{ .name = "y", .type = "f32" },
        .{ .name = "width", .type = "f32" },
        .{ .name = "height", .type = "f32" },
    }, .ret = "void", .js = 
    \\canvas.strokeRect(x,y,width,height);
    },
    Func{ .name = "setFillStyle_rgba", .args = &[_]Arg{
        .{ .name = "r", .type = "u8" },
        .{ .name = "g", .type = "u8" },
        .{ .name = "b", .type = "u8" },
        .{ .name = "a", .type = "u8" },
    }, .ret = "void", .js = 
    \\// make alpha work; apparently it only accepts floats
    \\const alpha = a / 255.0;
    \\canvas.fillStyle = `rgba(${r},${g},${b},${alpha})`;
    },
    Func{ .name = "setStrokeStyle_rgba", .args = &[_]Arg{
        .{ .name = "r", .type = "u8" },
        .{ .name = "g", .type = "u8" },
        .{ .name = "b", .type = "u8" },
        .{ .name = "a", .type = "u8" },
    }, .ret = "void", .js = 
    \\canvas.strokeStyle = `rgba(${r},${g},${b},${a})`;
    },
    Func{ .name = "setTextAlign", .args = &[_]Arg{
        .{ .name = "text_align", .type = "u8" },
    }, .ret = "void", .js = 
    \\canvas.textAlign = textAlignMap[text_align];
    },
    Func{ .name = "setTextBaseline", .args = &[_]Arg{
        .{ .name = "text_baseline", .type = "u8" },
    }, .ret = "void", .js = 
    \\canvas.textBaseline = textBaselineMap[text_baseline];
    },
    Func{ .name = "setLineCap", .args = &[_]Arg{
        .{ .name = "line_cap", .type = "u8" },
    }, .ret = "void", .js = 
    \\canvas.lineCap = lineCapMap[line_cap];
    },
    Func{ .name = "setLineWidth", .args = &[_]Arg{
        .{ .name = "width", .type = "f32" },
    }, .ret = "void", .js = 
    \\canvas.lineWidth = width;
    },
    Func{ .name = "setLineDash", .args = &[_]Arg{
        .{ .name = "segments", .type = "SLICE(f32)" },
    }, .ret = "void", .js = 
    \\canvas.setLineDash(segments);
    },
    Func{ .name = "fillText", .args = &[_]Arg{
        .{ .name = "text", .type = "STRING" },
        .{ .name = "x", .type = "f32" },
        .{ .name = "y", .type = "f32" },
    }, .ret = "void", .js = 
    \\canvas.fillText(text, x, y);
    },
    Func{ .name = "moveTo", .args = &[_]Arg{
        .{ .name = "x", .type = "f32" },
        .{ .name = "y", .type = "f32" },
    }, .ret = "void", .js = 
    \\canvas.moveTo(x, y);
    },
    Func{ .name = "lineTo", .args = &[_]Arg{
        .{ .name = "x", .type = "f32" },
        .{ .name = "y", .type = "f32" },
    }, .ret = "void", .js = 
    \\canvas.lineTo(x, y);
    },
    Func{ .name = "beginPath", .args = &[_]Arg{}, .ret = "void", .js = 
    \\canvas.beginPath();
    },
    Func{ .name = "stroke", .args = &[_]Arg{}, .ret = "void", .js = 
    \\canvas.stroke();
    },
    Func{ .name = "measureText", .args = &[_]Arg{
        .{ .name = "text", .type = "STRING" },
        .{ .name = "metricsOut", .type = "u32" },
    }, .ret = "void", .js = 
    \\const metrics = canvas.measureText(text);
    \\const metrics_map = getWasmTextMetricsMap();
    \\const metrics_wasm = new Float64Array(getMemory().buffer, metricsOut, metrics_map._size / 8);
    \\metrics_wasm[metrics_map.width / 8] = metrics.width;
    \\metrics_wasm[metrics_map.actualBoundingBoxAscent / 8] = metrics.actualBoundingBoxAscent;
    \\metrics_wasm[metrics_map.actualBoundingBoxDescent / 8] = metrics.actualBoundingBoxDescent;
    \\metrics_wasm[metrics_map.actualBoundingBoxLeft / 8] = metrics.actualBoundingBoxLeft;
    \\metrics_wasm[metrics_map.actualBoundingBoxRight / 8] = metrics.actualBoundingBoxRight;
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

    var stream = file.writer();

    try stream.print("{s}\n\n", .{zig_top});

    for (funcs) |func| {
        const any_slice = for (func.args) |arg| {
            if (std.mem.eql(u8, arg.type, "STRING") or std.mem.eql(u8, arg.type, "SLICE(f32)")) {
                break true;
            }
        } else false;

        // https://github.com/ziglang/zig/issues/3882
        const fmtarg_pub = if (any_slice) "" else "pub ";
        const fmtarg_suf = if (any_slice) "_" else "";
        try stream.print("{s}extern \"{s}\" fn {s}{s}(", .{ fmtarg_pub, extern_name, func.name, fmtarg_suf });
        for (func.args) |arg, i| {
            if (i > 0) {
                try stream.print(", ", .{});
            }
            if (std.mem.eql(u8, arg.type, "STRING")) {
                try stream.print("{s}_ptr: [*]const u8, {s}_len: c_uint", .{ arg.name, arg.name });
            } else if (std.mem.eql(u8, arg.type, "SLICE(f32)")) {
                try stream.print("{s}_ptr: [*]const f32, {s}_len: c_uint", .{ arg.name, arg.name });
            } else {
                try stream.print("{s}: {s}", .{ arg.name, arg.type });
            }
        }
        try stream.print(") {s};\n", .{func.ret});

        if (any_slice) {
            try stream.print("pub fn {s}(", .{func.name});
            for (func.args) |arg, i| {
                if (i > 0) {
                    try stream.print(", ", .{});
                }
                if (std.mem.eql(u8, arg.type, "STRING")) {
                    try stream.print("{s}: []const u8", .{arg.name});
                } else if (std.mem.eql(u8, arg.type, "SLICE(f32)")) {
                    try stream.print("{s}: []const f32", .{arg.name});
                } else {
                    try stream.print("{s}: {s}", .{ arg.name, arg.type });
                }
            }
            try stream.print(") {s} {{\n", .{func.ret});
            // https://github.com/ziglang/zig/issues/3882
            const fmtarg_ret = if (std.mem.eql(u8, func.ret, "void")) "" else "return ";
            try stream.print("    {s}{s}_(", .{ fmtarg_ret, func.name });
            for (func.args) |arg, i| {
                if (i > 0) {
                    try stream.print(", ", .{});
                }
                if (std.mem.eql(u8, arg.type, "STRING") or std.mem.eql(u8, arg.type, "SLICE(f32)")) {
                    try stream.print("{s}.ptr, {s}.len", .{ arg.name, arg.name });
                } else {
                    try stream.print("{s}", .{arg.name});
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

    var stream = file.writer();

    try stream.print("{s}\n", .{js_top});

    try stream.print("    return {{\n", .{});
    for (funcs) |func| {
        const any_slice = for (func.args) |arg| {
            if (std.mem.eql(u8, arg.type, "STRING") or std.mem.eql(u8, arg.type, "SLICE(f32)")) {
                break true;
            }
        } else false;

        // https://github.com/ziglang/zig/issues/3882
        const fmtarg_suf = if (any_slice) "_" else "";
        try stream.print("        {s}{s}(", .{ func.name, fmtarg_suf });
        for (func.args) |arg, i| {
            if (i > 0) {
                try stream.print(", ", .{});
            }
            if (std.mem.eql(u8, arg.type, "STRING") or std.mem.eql(u8, arg.type, "SLICE(f32)")) {
                try stream.print("{s}_ptr, {s}_len", .{ arg.name, arg.name });
            } else {
                try stream.print("{s}", .{arg.name});
            }
        }
        try stream.print(") {{\n", .{});
        for (func.args) |arg| {
            if (std.mem.eql(u8, arg.type, "STRING")) {
                try stream.print("            const {s} = readCharStr({s}_ptr, {s}_len);\n", .{ arg.name, arg.name, arg.name });
            } else if (std.mem.eql(u8, arg.type, "SLICE(f32)")) {
                try stream.print("            const {s} = readF32Array({s}_ptr, {s}_len);\n", .{ arg.name, arg.name, arg.name });
            }
        }
        var start: usize = 0;
        while (start < func.js.len) {
            const rel_newline_pos = nextNewline(func.js[start..]);
            try stream.print("            {s}\n", .{func.js[start .. start + rel_newline_pos]});
            start += rel_newline_pos + 1;
        }
        try stream.print("        }},\n", .{});
    }
    try stream.print("    }};\n", .{});

    try stream.print("{s}\n", .{js_bottom});
}

pub fn main() !void {
    try writeZigFile("canvas/web/canvas_generated.zig");
    try writeJsFile("static/canvas_generated.js");
}
