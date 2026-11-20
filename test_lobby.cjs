const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

// Exercise the actual browser bridge with a minimal DOM, without WebRTC or a browser.
function lobby(hash = "") {
  const html = fs.readFileSync(`${__dirname}/web/index.html`, "utf8");
  const elements = Object.fromEntries([...html.matchAll(/id="([^"]+)"/g)].map(([, id]) => [id, {
    id, hidden: false, value: "", checked: false, textContent: "",
    addEventListener() {}, focus() {}, querySelector() { return { focus() {} }; },
  }]));
  const saved = new Map();
  const context = vm.createContext({
    document: { querySelectorAll: () => Object.values(elements), body: { dataset: {} } },
    window: {}, location: { hash }, URLSearchParams, URL,
    localStorage: { getItem: key => saved.get(key), setItem: (key, value) => saved.set(key, value) },
    addEventListener() {}, setInterval() {}, clearTimeout() {},
  });
  vm.runInContext(fs.readFileSync(`${__dirname}/web/lobby.js`, "utf8"), context);
  return { context, elements, saved, bridge: context.window.GarageDay };
}

const page = lobby("#multiplayer");
assert.equal(page.elements.multiplayer.hidden, false, "The native link must open multiplayer directly");
assert.equal(page.elements.home.hidden, true);
page.bridge.setDisplay("fast", true);
assert.equal(page.elements.quality.value, "fast");
assert.equal(page.elements["show-fps"].checked, true);
assert.deepEqual(JSON.parse(page.saved.get("garage-day.display.v1")), { quality: "fast", showFps: true });
assert.equal(JSON.parse(page.bridge.startInfo()).quality, "fast");
page.bridge.setDisplay("invalid", false);
assert.equal(page.elements.quality.value, "fast", "Invalid settings must be ignored");
vm.runInContext('ready = resumable = true; gameControls = () => {};', page.context);
page.bridge.returnToMenu();
assert.equal(page.elements.home.hidden, false, "Returning from a solo pause must show home");
assert.equal(page.elements.game.hidden, true);
assert.equal(vm.runInContext("paused", page.context), true, "Returning home must preserve the running solo");
assert.equal(lobby().elements.home.hidden, false);
assert.equal(lobby("#join=gd-" + "a".repeat(32)).elements.invited.hidden, false);

const sharing = lobby();
const sharingChanges = [];
let pendingFrame;
let captureCount = 0;
let stopped = false;
let cancelled = false;
const track = { requestFrame() { captureCount++; }, stop() { stopped = true; } };
sharing.context.captureCanvas = {
  ownerDocument: { defaultView: {
    performance: { now: () => 10 },
    setGarageSharing: active => sharingChanges.push(active),
    requestAnimationFrame(callback) { pendingFrame = callback; return 42; },
    cancelAnimationFrame(id) { assert.equal(id, 42); pendingFrame = undefined; cancelled = true; },
  } },
  captureStream(rate) {
    assert.equal(rate, 0);
    return { getVideoTracks: () => [track], getTracks: () => [track] };
  },
};
vm.runInContext("stream = captureVideo(captureCanvas)", sharing.context);
for (const time of [10, 27, 43, 60, 78, 300, 308]) pendingFrame(time);
assert.equal(captureCount, 4, "Capture should skip extra draws and avoid catch-up bursts");
assert.deepEqual(sharingChanges, [true]);
vm.runInContext("clearConnection()", sharing.context);
assert.deepEqual(sharingChanges, [true, false]);
assert.ok(stopped && cancelled && !pendingFrame, "Disconnect must release the track and capture loop");

const fallbackRates = [];
const fallbackTrack = { stop() { fallbackRates.push("stop"); } };
sharing.context.captureCanvas.captureStream = rate => {
  fallbackRates.push(rate);
  return { getVideoTracks: () => [fallbackTrack], getTracks: () => [fallbackTrack] };
};
vm.runInContext("stream = captureVideo(captureCanvas); clearConnection()", sharing.context);
assert.deepEqual(fallbackRates, [0, "stop", 30, "stop"]);
assert.deepEqual(sharingChanges, [true, false, true, false]);

// The full window remains visible while graphics quality limits the actual pixel buffer.
const shell = fs.readFileSync(`${__dirname}/web/game-shell.html`, "utf8");
const script = shell.match(/<script>([\s\S]*?)<\/script>/)[1].replace("$GODOT_CONFIG", "{}");
const canvas = { clientWidth: 1500, clientHeight: 950 };
const loading = { querySelector: () => ({}), remove() {} };
let resize;
const frame = vm.createContext({
  window: {}, devicePixelRatio: 2,
  addEventListener(event, callback) { if (event === "resize") resize = callback; },
  document: { getElementById: id => id === "canvas" ? canvas : loading },
  Engine: class {
    startGame(options) {
      assert.equal(options.canvasResizePolicy, 0);
      return Promise.resolve();
    }
  },
});
vm.runInContext(script, frame);
assert.deepEqual([canvas.width, canvas.height], [1263, 800]);
frame.window.setGarageQuality("fast");
assert.deepEqual([canvas.width, canvas.height], [947, 600]);
frame.window.setGarageQuality("high");
assert.deepEqual([canvas.width, canvas.height], [1895, 1200]);
frame.window.setGarageSharing(true);
assert.deepEqual([canvas.width, canvas.height], [947, 600]);
frame.window.setGarageQuality("balanced");
assert.deepEqual([canvas.width, canvas.height], [947, 600], "Sharing should keep its cap if quality changes");
frame.window.setGarageSharing(false);
assert.deepEqual([canvas.width, canvas.height], [1263, 800], "Disconnect should restore the selected quality");
canvas.clientWidth = 640;
canvas.clientHeight = 400;
resize();
assert.deepEqual([canvas.width, canvas.height], [1280, 800]);
canvas.clientWidth = 0;
canvas.clientHeight = 0;
resize();
assert.deepEqual([canvas.width, canvas.height], [1280, 800], "Hiding the iframe should preserve its buffer");
console.log("PASS: capped Web rendering across graphics modes, resize, and hidden iframe.");
console.log("PASS: paced capture, browser fallback, and cleanup on disconnect.");
console.log("PASS: multiplayer link, display settings bridge, solo return to home, invitations.");
