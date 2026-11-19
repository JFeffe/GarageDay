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
console.log("PASS: multiplayer link, display settings bridge, solo return to home, invitations.");
