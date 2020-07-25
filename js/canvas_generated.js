export default function getWebGLEnv(canvas_element, getMemory) {
    const utf8decoder = new TextDecoder();
    const readCharStr = (ptr, len) =>
        utf8decoder.decode(new Uint8Array(getMemory().buffer, ptr, len));
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

    const canvas = canvas_element.getContext('2d');

    const textAlignMap = ["left", "right", "center"];
    return {
        getScreenW() {
            return canvas_element.getBoundingClientRect().width;
        },
        getScreenH() {
            return canvas_element.getBoundingClientRect().height;
        },
        canvas_clearRect(x, y, width, height) {
            canvas.clearRect(x,y,width,height);
        },
        canvas_fillRect(x, y, width, height) {
            canvas.fillRect(x,y,width,height);
        },
        canvas_setFillStyle_rgba(r, g, b, a) {
            canvas.fillStyle = `rgba(${r},${g},${b},${a})`;
        },
        canvas_setTextAlign(text_align) {
            canvas.textAlign = textAlignMap[text_align];
        },
        canvas_fillText_(text_ptr, text_len, x, y) {
            const text = readCharStr(text_ptr, text_len);
            canvas.fillText(text, x, y);
        },
    };
}
