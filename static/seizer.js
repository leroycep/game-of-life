// Promises with an id, so that it can be passed to WASM
var idpromise_promises = {};
var idpromise_open_ids = [];

function idpromise_call(func, args) {
    let params = args || [];
    return new Promise((resolve, reject) => {
        let id = Object.keys(idpromise_promises).length;
        if (idpromise_open_ids.length > 0) {
            id = idpromise_open_ids.pop();
        }
        idpromise_promises[id] = { resolve, reject };
        func(id, ...params);
    });
}

function idpromise_reject(id, errno) {
    idpromise_promises[id].reject(errno);
    idpromise_open_ids.push(id);
    delete idpromise_promises[id];
}

function idpromise_resolve(id, data) {
    idpromise_promises[id].resolve(data);
    idpromise_open_ids.push(id);
    delete idpromise_promises[id];
}

// Platform ENV
export default function getPlatformEnv(canvas_element, getInstance) {
    const getMemory = () => getInstance().exports.memory;
    const utf8decoder = new TextDecoder();
    const readCharStr = (ptr, len) =>
        utf8decoder.decode(new Uint8Array(getMemory().buffer, ptr, len));
    const writeCharStr = (ptr, len, lenRetPtr, text) => {
        const encoder = new TextEncoder();
        const message = encoder.encode(text);
        const zigbytes = new Uint8Array(getMemory().buffer, ptr, len);
        let zigidx = 0;
        for (const b of message) {
            if (zigidx >= len - 1) break;
            zigbytes[zigidx] = b;
            zigidx += 1;
        }
        zigbytes[zigidx] = 0;
        if (lenRetPtr !== 0) {
            new Uint32Array(getMemory().buffer, lenRetPtr, 1)[0] = zigidx;
        }
    };

    function getErrorName(errno) {
        const instance = getInstance();
        const ptr = instance.exports.wasm_error_name_ptr(errno);
        const len = instance.exports.wasm_error_name_len(errno);
        return utf8decoder.decode(new Uint8Array(getMemory().buffer, ptr, len));
    }

    const initFinished = (maxDelta, tickDelta) => {
        const instance = getInstance();

        let prevTime = performance.now();
        let tickTime = 0.0;
        let accumulator = 0.0;

        function step(currentTime) {
            let delta = (currentTime - prevTime) / 1000; // Delta in seconds
            if (delta > maxDelta) {
                delta = maxDelta; // Try to avoid spiral of death when lag hits
            }
            prevTime = currentTime;

            accumulator += delta;

            while (accumulator >= tickDelta) {
                instance.exports.update(tickTime, tickDelta);
                accumulator -= tickDelta;
                tickTime += tickDelta;
            }

            // Where the render is between two timesteps.
            // If we are halfway between frames (based on what's in the accumulator)
            // then alpha will be equal to 0.5
            const alpha = accumulator / tickDelta;

            instance.exports.render(alpha);

            if (running) {
                window.requestAnimationFrame(step);
            }
        }
        window.requestAnimationFrame(step);

        const ex = instance.exports;
        const keyMap = {
            Unknown: ex.KEYCODE_UNKNOWN,
            Backspace: ex.KEYCODE_BACKSPACE,
        };
        const codeMap = {
            Unknown: ex.SCANCODE_UNKNOWN,
            KeyW: ex.SCANCODE_W,
            KeyA: ex.SCANCODE_A,
            KeyS: ex.SCANCODE_S,
            KeyD: ex.SCANCODE_D,
            KeyZ: ex.SCANCODE_Z,
            KeyR: ex.SCANCODE_R,
            ArrowLeft: ex.SCANCODE_LEFT,
            ArrowRight: ex.SCANCODE_RIGHT,
            ArrowUp: ex.SCANCODE_UP,
            ArrowDown: ex.SCANCODE_DOWN,
            Escape: ex.SCANCODE_ESCAPE,
            Space: ex.SCANCODE_SPACE,
            Numpad0: ex.SCANCODE_NUMPAD0,
            Numpad1: ex.SCANCODE_NUMPAD1,
            Numpad2: ex.SCANCODE_NUMPAD2,
            Numpad3: ex.SCANCODE_NUMPAD3,
            Numpad4: ex.SCANCODE_NUMPAD4,
            Numpad5: ex.SCANCODE_NUMPAD5,
            Numpad6: ex.SCANCODE_NUMPAD6,
            Numpad7: ex.SCANCODE_NUMPAD7,
            Numpad8: ex.SCANCODE_NUMPAD8,
            Numpad9: ex.SCANCODE_NUMPAD9,
        };
        document.addEventListener("keydown", (ev) => {
            if (document.activeElement != canvas_element) return;

            if (ev.defaultPrevented) {
                return;
            }
            ev.preventDefault();

            let zigKeyConst = keyMap[ev.key];
            if (!zigKeyConst) {
                zigKeyConst = keyMap.Unknown;
            }

            let zigScancodeConst = codeMap[ev.code];
            if (!zigScancodeConst) {
                zigScancodeConst = codeMap.Unknown;
            }

            const zigKey = new Uint16Array(
                getMemory().buffer,
                zigKeyConst,
                1
            )[0];
            const zigScancode = new Uint16Array(
                getMemory().buffer,
                zigScancodeConst,
                1
            )[0];
            instance.exports.onKeyDown(zigKey, zigScancode);

            if (!ev.isComposing) {
                switch (ev.key) {
                    case "Unidentified":
                    case "Alt":
                    case "AltGraph":
                    case "CapsLock":
                    case "Control":
                    case "Fn":
                    case "FnLock":
                    case "Hyper":
                    case "Meta":
                    case "NumLock":
                    case "ScrollLock":
                    case "Shift":
                    case "Super":
                    case "Symbol":
                    case "SymbolLock":
                    case "Enter":
                    case "Tab":
                    case "ArrowDown":
                    case "ArrowLeft":
                    case "ArrowRight":
                    case "ArrowUp":
                    case "OS":
                    case "Escape":
                    case "Backspace":
                        // Don't send text input events for special keys
                        return;
                    default:
                        break;
                }
                const zigbytes = new Uint8Array(
                    getMemory().buffer,
                    instance.exports.TEXT_INPUT_BUFFER,
                    32
                );

                const encoder = new TextEncoder();
                const message = encoder.encode(ev.key);

                let zigidx = 0;
                for (const b of message) {
                    if (zigidx >= 32 - 1) break;
                    zigbytes[zigidx] = b;
                    zigidx += 1;
                }
                zigbytes[zigidx] = 0;

                instance.exports.onTextInput(zigidx);
            }
        });

        const mouseBtnCodeMap = [
            ex.MOUSE_BUTTON_LEFT,
            ex.MOUSE_BUTTON_MIDDLE,
            ex.MOUSE_BUTTON_RIGHT,
            ex.MOUSE_BUTTON_X1,
            ex.MOUSE_BUTTON_X2,
        ];

        canvas_element.addEventListener("contextmenu", (ev) => {
            ev.preventDefault();
        });

        canvas_element.addEventListener("mousemove", (ev) => {
            const rect = canvas_element.getBoundingClientRect();
            instance.exports.onMouseMove(
                ev.x - rect.left,
                ev.y - rect.top,
                ev.movementX,
                ev.movementY,
                ev.buttons
            );
        });

        canvas_element.addEventListener("mousedown", (ev) => {
            canvas_element.focus();
            const rect = canvas_element.getBoundingClientRect();
            const zigConst = mouseBtnCodeMap[ev.button];
            if (zigConst !== undefined) {
                const zigCode = new Uint8Array(getMemory().buffer, zigConst, 1)[0];
                instance.exports.onMouseButton(
                    ev.x - rect.left,
                    ev.y - rect.top,
                    1,
                    zigCode
                );
            }
        });

        canvas_element.addEventListener("mouseup", (ev) => {
            const rect = canvas_element.getBoundingClientRect();
            const zigConst = mouseBtnCodeMap[ev.button];
            if (zigConst !== undefined) {
                const zigCode = new Uint8Array(getMemory().buffer, zigConst, 1)[0];
                instance.exports.onMouseButton(
                    ev.x - rect.left,
                    ev.y - rect.top,
                    0,
                    zigCode
                );
            }
        });

        canvas_element.addEventListener("wheel", (ev) => {
            ev.preventDefault();
            instance.exports.onMouseWheel(ev.deltaX, ev.deltaY);
        });

        document.addEventListener("keyup", (ev) => {
            if (ev.defaultPrevented) {
                return;
            }
            const zigConst = codeMap[ev.code];
            if (zigConst !== undefined) {
                const zigCode = new Uint16Array(
                    getMemory().buffer,
                    zigConst,
                    1
                )[0];
                instance.exports.onKeyUp(zigCode);
            }
        });
    };

    const gl = null; /*canvas_element.getContext("webgl2", {
        antialias: false,
        preserveDrawingBuffer: true,
    });*/

    //if (!gl) {
    //    throw new Error("The browser does not support WebGL");
    //}

    // Start resources arrays with a null value to ensure the id 0 is never returned
    const glShaders = [null];
    const glPrograms = [null];
    const glBuffers = [null];
    const glVertexArrays = [null];
    const glTextures = [null];
    const glFramebuffers = [null];
    const glUniformLocations = [null];

    // Set up errno constants to be filled in when `seizer_run` is called
    let ERRNO_OUT_OF_MEMORY = undefined;
    let ERRNO_FILE_NOT_FOUND = undefined;
    let ERRNO_UNKNOWN = undefined;

    let seizer_log_string = "";
    let running = true;

    return {
        seizer_run(maxDelta, tickDelta) {
            const instance = getInstance();

            // Load error numbers from WASM
            const dataview = new DataView(instance.exports.memory.buffer);
            ERRNO_OUT_OF_MEMORY = dataview.getUint32(
                instance.exports.ERRNO_OUT_OF_MEMORY,
                true
            );
            ERRNO_FILE_NOT_FOUND = dataview.getUint32(
                instance.exports.ERRNO_FILE_NOT_FOUND,
                true
            );
            ERRNO_UNKNOWN = dataview.getUint32(
                instance.exports.ERRNO_UNKNOWN,
                true
            );

            // TODO: call async init function
            idpromise_call(instance.exports.onInit).then((_data) => {
                initFinished(maxDelta, tickDelta);
            });
        },
        seizer_quit() {
            running = false;
        },
        seizer_log_write: (ptr, len) => {
            seizer_log_string += utf8decoder.decode(
                new Uint8Array(getMemory().buffer, ptr, len)
            );
        },
        seizer_log_flush: () => {
            console.log(seizer_log_string);
            seizer_log_string = "";
        },
        seizer_reject_promise: (id, errno) => {
            idpromise_reject(id, new Error(getErrorName(errno)));
        },
        seizer_resolve_promise: idpromise_resolve,

        seizer_fetch: (ptr, len, cb, ctx, allocator) => {
            const instance = getInstance();

            const filename = utf8decoder.decode(
                new Uint8Array(getMemory().buffer, ptr, len)
            );

            fetch(filename)
                .then((response) => {
                    if (!response.ok) {
                        instance.exports.wasm_fail_fetch(
                            cb,
                            ctx,
                            ERRNO_FILE_NOT_FOUND
                        );
                    }
                    return response.arrayBuffer();
                })
                .then((buffer) => new Uint8Array(buffer))
                .then(
                    (bytes) => {
                        const wasm_bytes_ptr = instance.exports.wasm_allocator_alloc(
                            allocator,
                            bytes.byteLength
                        );
                        if (wasm_bytes_ptr == 0) {
                            instance.exports.wasm_fail_fetch(
                                cb,
                                ctx,
                                ERRNO_OUT_OF_MEMORY
                            );
                        }

                        const wasm_bytes = new Uint8Array(
                            instance.exports.memory.buffer,
                            wasm_bytes_ptr,
                            bytes.byteLength
                        );
                        wasm_bytes.set(bytes);

                        instance.exports.wasm_finalize_fetch(
                            cb,
                            ctx,
                            wasm_bytes_ptr,
                            bytes.byteLength
                        );
                    },
                    (err) =>
                        instance.exports.wasm_fail_fetch(cb, ctx, ERRNO_UNKNOWN)
                );
        },
        seizer_random_bytes(ptr, len) {
            const bytes = new Uint8Array(getMemory().buffer, ptr, len);
            window.crypto.getRandomValues(bytes);
        },

        getScreenW() {
            return canvas_element.getBoundingClientRect().width;
        },
        getScreenH() {
            return canvas_element.getBoundingClientRect().height;
        },
    };
}
