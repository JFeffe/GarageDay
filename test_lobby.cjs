const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

// Exercise the actual browser bridge with a minimal DOM, without WebRTC or a browser.
function lobby(hash = "") {
  const html = fs.readFileSync(`${__dirname}/web/index.html`, "utf8");
  const elements = Object.fromEntries([...html.matchAll(/id="([^"]+)"/g)].map(([, id]) => [id, {
    id, hidden: false, value: "", checked: false, textContent: "",
    addEventListener() {}, focus() {}, querySelector() { return { focus() {} }; },
    removeAttribute(name) { delete this[name]; },
  }]));
  const saved = new Map();
  const tasks = [];
  const history = [];
  const context = vm.createContext({
    document: { querySelectorAll: () => Object.values(elements), body: { dataset: { game: "game.html" } } },
    window: {}, location: { hash, pathname: "/", search: "" }, URLSearchParams, URL, performance,
    history: { replaceState(_state, _title, url) { history.push(url); } },
    localStorage: { getItem: key => saved.get(key), setItem: (key, value) => saved.set(key, value) },
    addEventListener() {}, setInterval() {}, clearTimeout() {}, setTimeout(callback) { tasks.push(callback); },
  });
  vm.runInContext(fs.readFileSync(`${__dirname}/web/lobby.js`, "utf8"), context);
  return { context, elements, saved, tasks, history, bridge: context.window.GarageDay };
}

const page = lobby("#multiplayer");
const mapOptions = [...fs.readFileSync(`${__dirname}/web/index.html`, "utf8")
  .matchAll(/name="layout" value="(\d+)"( checked)?/g)];
assert.deepEqual(mapOptions.map(([, id]) => Number(id)), [3, 0, 1, 2]);
assert.equal(mapOptions[0][2], " checked", "The compact map must be selected by default");
assert.equal(JSON.parse(page.bridge.startInfo()).layout, 3);
const endurance = lobby();
assert.match(fs.readFileSync(`${__dirname}/web/index.html`, "utf8"), /<input type="radio" name="layout" value="endurance">/);
endurance.bridge.storeSave("garage-checkpoint");
vm.runInContext(`openPicker("solo"); startSelectedGame("endurance"); ready = true;
  gameControls = (action, value) => {
    if (action === "pause" && value) window.GarageDay.reportRacePause("00:03:00 · Reste 11:57:00");
  };`, endurance.context);
assert.equal(JSON.parse(endurance.bridge.startInfo()).activity, "endurance");
endurance.bridge.storeSave("race-state");
assert.equal(endurance.saved.get("garage-day.solo.v1"), "garage-checkpoint");
vm.runInContext("pauseSolo();", endurance.context);
assert.equal(endurance.elements["paused-race-clock"].hidden, false);
assert.match(endurance.elements["paused-race-clock"].textContent, /00:03:00.*11:57:00/);
vm.runInContext("continueGame();", endurance.context);
assert.equal(JSON.parse(endurance.bridge.startInfo()).activity, "endurance");
assert.equal(endurance.elements.game.hidden, false);
assert.equal(page.elements.multiplayer.hidden, false, "The native link must open multiplayer directly");
assert.equal(page.elements.home.hidden, true);
page.bridge.setDisplay("fast", true);
assert.equal(page.elements.quality.value, "fast");
assert.equal(page.elements["show-fps"].checked, true);
assert.deepEqual(JSON.parse(page.saved.get("garage-day.display.v1")), { quality: "fast", showFps: true });
assert.equal(JSON.parse(page.bridge.startInfo()).quality, "fast");
page.bridge.setDisplay("invalid", false);
assert.equal(page.elements.quality.value, "fast", "Invalid settings must be ignored");
vm.runInContext('openGame("solo"); ready = true; gameControls = () => {};', page.context);
page.bridge.returnToMenu();
assert.equal(page.elements.game.hidden, false, "The iframe must stay active until Godot's button handler returns");
page.tasks.shift()();
assert.equal(page.elements.home.hidden, false, "Returning from a solo pause must show home");
assert.equal(page.elements.game.hidden, true);
assert.equal(vm.runInContext("paused", page.context), true, "Returning home must preserve the running solo");
assert.equal(page.elements.resume.hidden, false, "A running solo can be resumed without a disk checkpoint");
assert.equal(page.elements["game-frame"].src, "game.html");
vm.runInContext("continueGame()", page.context);
assert.equal(page.elements.game.hidden, false, "Continuing should show the existing game");

const host = lobby();
const speedInput = lobby();
vm.runInContext(`openGame("host", 3, "", "endurance"); channel = { open: true };
  receiveInput(channel, [0, 0, 0, 0, 32, 0, 0]);`, speedInput.context);
assert.equal(JSON.parse(speedInput.bridge.guestInput())[8], 32, "RT should reach Godot as a single press");
assert.equal(JSON.parse(speedInput.bridge.guestInput())[8], 0);
vm.runInContext("receiveInput(channel, [0, 0, 0, 0, 16, 0, 0]);", speedInput.context);
assert.equal(JSON.parse(speedInput.bridge.guestInput())[8], 16, "LT should reach Godot as a single press");

vm.runInContext('openGame("host"); ready = true;', host.context);
host.bridge.returnToMenu();
assert.equal(host.elements["game-frame"].src, "game.html");
host.tasks.shift()();
assert.equal(host.elements.home.hidden, false);
assert.equal(host.elements["game-frame"].src, undefined);
vm.runInContext('openGame("host"); ready = true;', host.context);
host.bridge.returnToMenu();
vm.runInContext('openGame("solo"); ready = true;', host.context);
host.tasks.shift()();
assert.equal(host.elements.game.hidden, false, "An old return request must not close a new session");

const inviteHash = "#join=gd-" + "a".repeat(32);
const guest = lobby(inviteHash);
vm.runInContext('openGame("guest"); leaveGame();', guest.context);
assert.equal(guest.elements.home.hidden, false, "An explicit quit should return the guest to the main menu");
assert.deepEqual(guest.history, ["/"]);
const disconnected = lobby(inviteHash);
vm.runInContext('openGame("guest"); returnHome("Connexion interrompue.");', disconnected.context);
assert.equal(disconnected.elements.invited.hidden, false, "An unexpected disconnect should still let the guest retry");
assert.equal(lobby().elements.home.hidden, false);
assert.equal(lobby(inviteHash).elements.invited.hidden, false);

const sharing = lobby();
let pendingFrame;
let captureCount = 0;
let stopped = false;
let cancelled = false;
const track = { requestFrame() { captureCount++; }, stop() { stopped = true; } };
sharing.context.captureCanvas = {
  width: 1263,
  height: 800,
  ownerDocument: { defaultView: {
    performance: { now: () => 10 },
    requestAnimationFrame(callback) { pendingFrame = callback; return 42; },
    cancelAnimationFrame(id) { assert.equal(id, 42); pendingFrame = undefined; cancelled = true; },
  } },
  captureStream(rate) {
    assert.equal(rate, 0);
    assert.deepEqual([this.width, this.height], [1263, 800]);
    return { getVideoTracks: () => [track], getTracks: () => [track] };
  },
};
vm.runInContext("stream = captureVideo(captureCanvas)", sharing.context);
for (const time of [10, 27, 43, 60, 78, 300, 308]) pendingFrame(time);
assert.equal(captureCount, 4, "Capture should skip extra draws and avoid catch-up bursts");
vm.runInContext("clearConnection()", sharing.context);
assert.ok(stopped && cancelled && !pendingFrame, "Disconnect must release the track and capture loop");

const fallbackRates = [];
const fallbackTrack = { stop() { fallbackRates.push("stop"); } };
sharing.context.captureCanvas.captureStream = rate => {
  fallbackRates.push(rate);
  return { getVideoTracks: () => [fallbackTrack], getTracks: () => [fallbackTrack] };
};
vm.runInContext("stream = captureVideo(captureCanvas); clearConnection()", sharing.context);
assert.deepEqual(fallbackRates, [0, "stop", 30, "stop"]);

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
frame.window.setGarageQuality("balanced", true);
assert.deepEqual([canvas.width, canvas.height], [1421, 900], "Balanced solo should use the sharper buffer");
frame.window.setGarageQuality("balanced", false);
assert.deepEqual([canvas.width, canvas.height], [1263, 800], "Hosting should keep the existing capture size");
frame.window.setGarageQuality("fast");
assert.deepEqual([canvas.width, canvas.height], [947, 600]);
frame.window.setGarageQuality("high");
assert.deepEqual([canvas.width, canvas.height], [1895, 1200]);
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
