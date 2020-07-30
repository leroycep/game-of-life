export default function getWebGLEnv(canvas_element, getInstance) {
    const getMemory = () => getInstance().exports.memory;
    const utf8decoder = new TextDecoder();
    const readCharStr = (ptr, len) =>
        utf8decoder.decode(new Uint8Array(getMemory().buffer, ptr, len));
    const readF32Array = (ptr, len) =>
        new Float32Array(getMemory().buffer, ptr, len);
    const writeCharStr = (ptr, len, lenRetPtr, text) => {
        const encoder = new TextEncoder();
        const message = encoder.encode(text);
        const zigbytes = new Uint8Array(getMemory().buffer, ptr, len);
        let zigidx = 0;
        for (const b of message) {
            if (zigidx >= len-1) break;
            zigbytes[zigidx] = b;
            zigidx += 1;
        }
        zigbytes[zigidx] = 0;
        if (lenRetPtr !== 0) {
            new Uint32Array(getMemory().buffer, lenRetPtr, 1)[0] = zigidx;
        }
    }

    const readU32Const = (ptr) => new Uint32Array(getMemory().buffer, ptr, 1)[0];

    let wasmTextMetricsMap;
    const getWasmTextMetricsMap = () => {
        if (wasmTextMetricsMap) return wasmTextMetricsMap;
        wasmTextMetricsMap = {
            _size: readU32Const(getInstance().exports.TextMetrics_SIZE),
            width: readU32Const(getInstance().exports.TextMetrics_OFFSET_width),
            actualBoundingBoxAscent: readU32Const(getInstance().exports.TextMetrics_OFFSET_actualBoundingBoxAscent),
            actualBoundingBoxDescent: readU32Const(getInstance().exports.TextMetrics_OFFSET_actualBoundingBoxDescent),
            actualBoundingBoxLeft: readU32Const(getInstance().exports.TextMetrics_OFFSET_actualBoundingBoxLeft),
            actualBoundingBoxRight: readU32Const(getInstance().exports.TextMetrics_OFFSET_actualBoundingBoxRight),
        }
        return wasmTextMetricsMap;
    };

    const canvas = canvas_element.getContext('2d');

    const textAlignMap = ["left", "right", "center"];
    const textBaselineMap = ["top", "hanging", "middle", "alphabetic", "ideographic", "bottom"];
    const lineCapMap = ["butt", "round", "square"];
    const cursorStyleMap = ["default", "move", "grabbing"];
    return {
        getScreenW() {
            return canvas_element.getBoundingClientRect().width;
        },
        getScreenH() {
            return canvas_element.getBoundingClientRect().height;
        },
        canvas_setCursorStyle(style) {
            canvas_element.style.cursor = cursorStyleMap[style];
        },
        canvas_clearRect(x, y, width, height) {
            canvas.clearRect(x,y,width,height);
        },
        canvas_fillRect(x, y, width, height) {
            canvas.fillRect(x,y,width,height);
        },
        canvas_strokeRect(x, y, width, height) {
            canvas.strokeRect(x,y,width,height);
        },
        canvas_setFillStyle_rgba(r, g, b, a) {
            // make alpha work; apparently it only accepts floats
            const alpha = a / 255.0;
            canvas.fillStyle = `rgba(${r},${g},${b},${alpha})`;
        },
        canvas_setStrokeStyle_rgba(r, g, b, a) {
            canvas.strokeStyle = `rgba(${r},${g},${b},${a})`;
        },
        canvas_setTextAlign(text_align) {
            canvas.textAlign = textAlignMap[text_align];
        },
        canvas_setTextBaseline(text_baseline) {
            canvas.textBaseline = textBaselineMap[text_baseline];
        },
        canvas_setLineCap(line_cap) {
            canvas.lineCap = lineCapMap[line_cap];
        },
        canvas_setLineWidth(width) {
            canvas.lineWidth = width;
        },
        canvas_setLineDash_(segments_ptr, segments_len) {
            const segments = readF32Array(segments_ptr, segments_len);
            canvas.setLineDash(segments);
        },
        canvas_fillText_(text_ptr, text_len, x, y) {
            const text = readCharStr(text_ptr, text_len);
            canvas.fillText(text, x, y);
        },
        canvas_moveTo(x, y) {
            canvas.moveTo(x, y);
        },
        canvas_lineTo(x, y) {
            canvas.lineTo(x, y);
        },
        canvas_beginPath() {
            canvas.beginPath();
        },
        canvas_stroke() {
            canvas.stroke();
        },
        canvas_measureText_(text_ptr, text_len, metricsOut) {
            const text = readCharStr(text_ptr, text_len);
            const metrics = canvas.measureText(text);
            const metrics_map = getWasmTextMetricsMap();
            const metrics_wasm = new Float64Array(getMemory().buffer, metricsOut, metrics_map._size / 8);
            metrics_wasm[metrics_map.width / 8] = metrics.width;
            metrics_wasm[metrics_map.actualBoundingBoxAscent / 8] = metrics.actualBoundingBoxAscent;
            metrics_wasm[metrics_map.actualBoundingBoxDescent / 8] = metrics.actualBoundingBoxDescent;
            metrics_wasm[metrics_map.actualBoundingBoxLeft / 8] = metrics.actualBoundingBoxLeft;
            metrics_wasm[metrics_map.actualBoundingBoxRight / 8] = metrics.actualBoundingBoxRight;
        },
    };
}
