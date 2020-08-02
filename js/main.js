import getWebGLEnv from "./canvas_generated.js";

let container = document.getElementById("container");
let canvas = document.getElementById("canvas-webgl");
let componentsRoot = document.getElementById("components-root");
var memory;

var globalInstance;

let customEventCallback = eventId => {
    globalInstance.exports.onCustomEvent(eventId);
};

let env = {
  ...getWebGLEnv(canvas, () => globalInstance),
  consoleLogS: (ptr, len) => {
    const bytes = new Uint8Array(memory.buffer, ptr, len);
    let s = "";
    for (const b of bytes) {
      s += String.fromCharCode(b);
    }
    console.log(s);
  },
  requestFullscreen: () => {
    if (container.requestFullscreen) {
      container.requestFullscreen();
    }
  },
  now_f64: ptr => Date.now()
};

fetch("game-of-life-web.wasm")
  .then(response => response.arrayBuffer())
  .then(bytes => WebAssembly.instantiate(bytes, { env }))
  .then(results => results.instance)
  .then(instance => {
    memory = instance.exports.memory;
    globalInstance = instance;
    instance.exports.onInit();

    const SHOULD_QUIT = instance.exports.QUIT;

    // Timestep based on the Gaffer on Games post, "Fix Your Timestep"
    //    https://www.gafferongames.com/post/fix_your_timestep/
    const MAX_DELTA = new Float64Array(
      memory.buffer,
      instance.exports.MAX_DELTA_SECONDS,
      1
    )[0];
    const TICK_DELTA = new Float64Array(
      memory.buffer,
      instance.exports.TICK_DELTA_SECONDS,
      1
    )[0];
    let prevTime = performance.now();
    let tickTime = 0.0;
    let accumulator = 0.0;

    function step(currentTime) {
      let delta = (currentTime - prevTime) / 1000; // Delta in seconds
      if (delta > MAX_DELTA) {
        delta = MAX_DELTA; // Try to avoid spiral of death when lag hits
      }
      prevTime = currentTime;

      accumulator += delta;

      while (accumulator >= TICK_DELTA) {
        instance.exports.update(tickTime, TICK_DELTA);
        accumulator -= TICK_DELTA;
        tickTime += TICK_DELTA;
      }

      // Where the render is between two timesteps.
      // If we are halfway between frames (based on what's in the accumulator)
      // then alpha will be equal to 0.5
      const alpha = accumulator / TICK_DELTA;

      instance.exports.render(alpha);

      if (!instance.exports.hasQuit()) {
        window.requestAnimationFrame(step);
      } else {
        const quitLabel = document.createElement("p");
        quitLabel.textContent =
          "You have quit, game is stopped. Refresh the page to restart the game.";
        document.querySelector(".container").prepend(quitLabel);
      }
    }
    window.requestAnimationFrame(step);

    const ex = instance.exports;

    const mouseBtnCodeMap = [
        ex.MOUSE_BUTTON_LEFT,
        ex.MOUSE_BUTTON_MIDDLE,
        ex.MOUSE_BUTTON_RIGHT,
        ex.MOUSE_BUTTON_X1,
        ex.MOUSE_BUTTON_X2,
    ];

    canvas.addEventListener("contextmenu", ev => {
      ev.preventDefault();
    });

    canvas.addEventListener("mousemove", ev => {
      const rect = canvas.getBoundingClientRect();
      instance.exports.onMouseMove(ev.x - rect.left, ev.y - rect.top, ev.buttons);
    });

    canvas.addEventListener("mousedown", (ev) => {
      canvas.focus();
      const rect = canvas.getBoundingClientRect();
      const zigConst = mouseBtnCodeMap[ev.button];
      if (zigConst !== undefined) {
        const zigCode = new Uint8Array(memory.buffer, zigConst, 1)[0];
        instance.exports.onMouseButton(ev.x - rect.left, ev.y - rect.top, 1, zigCode);
      }
    });

    canvas.addEventListener("mouseup", (ev) => {
      const rect = canvas.getBoundingClientRect();
      const zigConst = mouseBtnCodeMap[ev.button];
      if (zigConst !== undefined) {
        const zigCode = new Uint8Array(memory.buffer, zigConst, 1)[0];
        instance.exports.onMouseButton(ev.x - rect.left, ev.y - rect.top, 0, zigCode);
      }
    });

    canvas.addEventListener("wheel", (ev) => {
      ev.preventDefault();
      instance.exports.onMouseWheel(ev.deltaX, ev.deltaY);
    });

    const keyMap = {
        Unknown: ex.SCANCODE_UNKNOWN,
        Backspace: ex.SCANCODE_BACKSPACE,
    };
    const codeMap = {
      Unknown: ex.SCANCODE_UNKNOWN,
      KeyW: ex.SCANCODE_W,
      KeyA: ex.SCANCODE_A,
      KeyS: ex.SCANCODE_S,
      KeyD: ex.SCANCODE_D,
      KeyZ: ex.SCANCODE_Z,
      ArrowLeft: ex.SCANCODE_LEFT,
      ArrowRight: ex.SCANCODE_RIGHT,
      ArrowUp: ex.SCANCODE_UP,
      ArrowDown: ex.SCANCODE_DOWN,
      Escape: ex.SCANCODE_ESCAPE,
      Space: ex.SCANCODE_SPACE
    };
    document.addEventListener("keydown", ev => {
      if (document.activeElement != canvas) return;

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

      const zigKey = new Uint16Array(memory.buffer, zigKeyConst, 1)[0];
      const zigScancode = new Uint16Array(memory.buffer, zigScancodeConst, 1)[0];
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
        const zigbytes = new Uint8Array(memory.buffer, instance.exports.TEXT_INPUT_BUFFER, 32);

        const encoder = new TextEncoder();
        const message = encoder.encode(ev.key);

        let zigidx = 0;
        for (const b of message) {
            if (zigidx >= 32-1) break;
            zigbytes[zigidx] = b;
            zigidx += 1;
        }
        zigbytes[zigidx] = 0;

        instance.exports.onTextInput(zigidx);
      }
    });

    document.addEventListener("keyup", ev => {
      if (ev.defaultPrevented) {
        return;
      }
      const zigConst = codeMap[ev.code];
      if (zigConst !== undefined) {
        const zigCode = new Uint16Array(memory.buffer, zigConst, 1)[0];
        instance.exports.onKeyUp(zigCode);
      }
    });

    const onResize = () => {
      instance.exports.onResize();
    };
    onResize();
    window.addEventListener("resize", onResize);
    new ResizeObserver(onResize).observe(document.body);

    window.addEventListener("fullscreenchange", (event) => {
        const rect = container.getBoundingClientRect();
        canvas.width = rect.width;
        canvas.height = rect.height;
    });
  });
