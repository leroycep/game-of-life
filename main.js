import getCanvasEnv from "./canvas_generated.js";
import getSeizerEnv from "./seizer.js";

let container = document.getElementById("container");
let canvas = document.getElementById("canvas-webgl");

var globalInstance;

let customEventCallback = (eventId) => {
    globalInstance.exports.onCustomEvent(eventId);
};

let imports = {
    canvas: getCanvasEnv(canvas, () => globalInstance),
    env: getSeizerEnv(canvas, () => globalInstance),
};

fetch("game-of-life-web.wasm")
    .then((response) => response.arrayBuffer())
    .then((bytes) => WebAssembly.instantiate(bytes, imports))
    .then((results) => results.instance)
    .then((instance) => {
        globalInstance = instance;
        instance.exports._start();
    });
