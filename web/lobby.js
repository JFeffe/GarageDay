"use strict";

const elements = Object.fromEntries([...document.querySelectorAll("[id]")].map(el => [el.id, el]));
const saveKeys = { solo: "garage-day.solo.v1", host: "garage-day.host.v1" };
const settingsKey = "garage-day.display.v1";
const qualities = {
  fast: "Affichage jusqu’à 960 × 600, avec les ombres désactivées.",
  balanced: "Image nette jusqu’à 1440 × 900 en solo, avec des ombres simplifiées.",
  high: "Affichage jusqu’à 1920 × 1200, ombres détaillées et contours lissés en solo.",
};
const protocol = 2;
const captureFps = 30;
let invitation = new URLSearchParams(location.hash.slice(1)).get("join");
const validRoom = id => /^gd-[0-9a-f]{32}$/.test(id ?? "");
const openInput = [0, 0, 0, 0, 0, 0, 0];
const defaultLayout = 3;
let launch = { mode: "solo", layout: defaultLayout, save: "", activity: "workshop" };
let peer, channel, call, stream, timeout;
let stopCapturing;
let gameSound;
let ready = false;
let paused = false;
let gameControls;
let pickerMode = "solo";
let screen = "home";
let lastInput = openInput;
let pressed = 0;
let lastInputAt = 0;
const keys = new Set();

function loadSave(mode) {
  try { return localStorage.getItem(saveKeys[mode]) || ""; }
  catch { return ""; }
}

function loadSettings() {
  try {
    const saved = JSON.parse(localStorage.getItem(settingsKey));
    if (saved && Object.hasOwn(qualities, saved.quality)) {
      return { quality: saved.quality, showFps: saved.showFps === true };
    }
  } catch { /* Use the default when storage is unavailable. */ }
  return { quality: "balanced", showFps: false };
}

let settings = loadSettings();

window.GarageDay = {
  startInfo: () => JSON.stringify({ ...launch, ...settings }),
  setDisplay(quality, showFps) {
    if (!Object.hasOwn(qualities, quality)) return;
    settings = { quality, showFps: showFps === true };
    elements.quality.value = quality;
    elements["show-fps"].checked = settings.showFps;
    try { localStorage.setItem(settingsKey, JSON.stringify(settings)); } catch { /* Apply for this tab. */ }
    updateDisplay();
  },
  returnToMenu() {
    const session = launch;
    // Wait until Godot returns from its button handler before calling back into
    // the engine or unloading its iframe.
    setTimeout(() => {
      if (session === launch && !elements.game.hidden) leaveGame();
    }, 0);
  },
  gameReady(controls) {
    gameControls = controls;
    ready = true;
    focusGame();
    if (launch.mode === "host") {
      showInvitation();
      if (channel?.open) shareGame();
    } else elements["room-status"].textContent = "";
  },
  reportFps(fps) {
    elements.fps.textContent = `${fps} i/s`;
  },
  guestInput() {
    const online = !!channel?.open && launch.mode === "host";
    const recent = online && performance.now() - lastInputAt < 600;
    const response = JSON.stringify([online, ...(recent ? lastInput : openInput), recent ? pressed : 0]);
    pressed = 0;
    return response;
  },
  gameAudio(encoded, sampleRate) {
    if (!stream || !gameSound || gameSound.context.state !== "running") return;
    const { context, destination } = gameSound;
    const binary = atob(encoded);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < bytes.length; i++) bytes[i] = binary.charCodeAt(i);
    const samples = new Float32Array(bytes.buffer);
    const buffer = context.createBuffer(2, samples.length / 2, sampleRate);
    const left = buffer.getChannelData(0);
    const right = buffer.getChannelData(1);
    for (let i = 0; i < left.length; i++) {
      left[i] = samples[i * 2];
      right[i] = samples[i * 2 + 1];
    }
    const source = context.createBufferSource();
    source.buffer = buffer;
    source.connect(destination);
    const now = context.currentTime;
    if (gameSound.cursor < now || gameSound.cursor > now + .25) gameSound.cursor = now + .045;
    source.start(gameSound.cursor);
    gameSound.cursor += buffer.duration;
  },
  storeSave(data) {
    if (launch.activity === "endurance") return;
    const key = saveKeys[launch.mode];
    if (!key) return;
    try {
      if (data) localStorage.setItem(key, data);
      else localStorage.removeItem(key);
    } catch {
      elements["room-status"].textContent = "Le navigateur bloque la sauvegarde locale.";
    }
  },
};

function focusGame() {
  elements["game-frame"].contentDocument?.querySelector("canvas")?.focus();
}

function showScreen(next, focus = true, message = "") {
  for (const name of ["home", "map-screen", "multiplayer", "invited", "options", "patch-notes"]) {
    elements[name].hidden = name !== next;
  }
  screen = next;
  elements.back.hidden = next === "home";
  elements.resume.hidden = !(paused || loadSave("solo") || loadSave("host"));
  elements["resume-host"].hidden = !loadSave("host");
  elements.notice.textContent = message;
  if (focus) {
    const heading = next === "home"
      ? (elements.resume.hidden ? elements["new-game"] : elements.resume)
      : elements[next].querySelector("h2");
    heading.focus();
  }
}

function openPicker(mode) {
  pickerMode = mode;
  elements.start.textContent = mode === "host" ? "Héberger" : "Jouer";
  showScreen("map-screen");
}

function updateDisplay() {
  elements["quality-details"].textContent = qualities[settings.quality];
  elements.fps.hidden = !settings.showFps || launch.mode === "guest";
  if (elements.fps.hidden) elements.fps.textContent = "";
}

function openGame(mode, layout = defaultLayout, save = "", activity = "workshop") {
  launch = { mode, layout, save, activity };
  ready = paused = false;
  gameControls = undefined;
  elements.lobby.hidden = true;
  elements.game.hidden = false;
  elements.room.hidden = false;
  elements.invite.hidden = true;
  elements.sound.hidden = true;
  elements.fps.textContent = "";
  updateDisplay();
  elements.exit.textContent = mode === "solo" ? "Menu" : "Quitter";
  elements["invite-url"].hidden = true;
  elements["room-status"].textContent = "Chargement…";
  elements["guest-view"].hidden = mode !== "guest";
  elements["game-frame"].hidden = mode === "guest";
  if (mode !== "guest") elements["game-frame"].src = document.body.dataset.game;
}

function pauseSolo() {
  if (!ready) {
    returnHome();
    return;
  }
  gameControls("pause", true);
  paused = true;
  elements.game.hidden = true;
  elements.lobby.hidden = false;
  showScreen("home");
}

function continueGame() {
  if (paused) {
    paused = false;
    elements.lobby.hidden = true;
    elements.game.hidden = false;
    gameControls("graphics", settings.quality, settings.showFps);
    gameControls("pause", false);
    focusGame();
  } else {
    const solo = loadSave("solo");
    const hosted = loadSave("host");
    if (solo) openGame("solo", defaultLayout, solo);
    else if (hosted) hostGame(defaultLayout, hosted);
  }
}

function clearInvitation() {
  if (invitation === null) return;
  invitation = null;
  history.replaceState(null, "", location.pathname + location.search);
}

function leaveGame() {
  if (launch.mode === "solo") {
    pauseSolo();
  } else {
    if (launch.mode === "guest") clearInvitation();
    returnHome();
  }
}

function returnHome(message = "") {
  const oldPeer = peer;
  peer = undefined;
  clearTimeout(timeout);
  clearConnection();
  gameSound?.context.close().catch(() => {});
  gameSound = undefined;
  oldPeer?.destroy();
  ready = paused = false;
  gameControls = undefined;
  keys.clear();
  elements["game-frame"].removeAttribute("src");
  elements["guest-view"].srcObject = null;
  elements.game.hidden = true;
  elements.lobby.hidden = false;
  showScreen(invitation !== null ? "invited" : "home", true, message);
}

function clearConnection() {
  const oldChannel = channel;
  const oldCall = call;
  channel = call = undefined;
  oldChannel?.close();
  oldCall?.close();
  stopCapturing?.();
  stopCapturing = undefined;
  stream?.getTracks().forEach(track => track.stop());
  stream = undefined;
  if (gameSound) gameSound.cursor = 0;
  lastInput = openInput;
  pressed = lastInputAt = 0;
}

function inviteLink(id) {
  const url = new URL("./", location.href);
  url.hash = new URLSearchParams({ join: id });
  return url.href;
}

function peerFor(id) {
  if (typeof Peer !== "function" || !window.RTCPeerConnection || !window.isSecureContext) {
    throw new Error("Le multijoueur WebRTC est indisponible dans ce navigateur.");
  }
  return id ? new Peer(id) : new Peer();
}

function showInvitation() {
  if (!ready || !peer?.open) return;
  elements["invite-url"].value = inviteLink(peer.id);
  elements.invite.hidden = false;
  if (!channel?.open) elements["room-status"].textContent = "En attente d’un invité";
}

function hostGame(layout, save = "", activity = "workshop") {
  const resumeNote = launch.activity === "endurance" ? "La course solo prendra fin." : "La reprise solo se fera au dernier atelier libre sauvegardé.";
  if (paused && !confirm("Fermer le solo pour héberger ? " + resumeNote)) return;
  try {
    const id = "gd-" + crypto.randomUUID().replaceAll("-", "");
    peer = peerFor(id);
    const Audio = window.AudioContext || window.webkitAudioContext;
    if (Audio) {
      const context = new Audio();
      gameSound = { context, destination: context.createMediaStreamDestination(), cursor: 0 };
      context.resume().catch(() => {});
    }
    openGame("host", layout, save, activity);
    const roomPeer = peer;
    elements["room-status"].textContent = "Création du lien…";
    roomPeer.on("open", () => {
      if (peer !== roomPeer) return;
      if (ready) showInvitation();
      else elements["room-status"].textContent = "Chargement du garage…";
    });
    roomPeer.on("connection", incoming => {
      if (peer !== roomPeer || channel || incoming.metadata?.protocol !== protocol) {
        incoming.close();
        return;
      }
      channel = incoming;
      incoming.on("open", () => {
        if (channel !== incoming) return;
        clearTimeout(timeout);
        elements["room-status"].textContent = "Invité connecté";
        if (ready) shareGame();
      });
      incoming.on("data", input => receiveInput(incoming, input));
      incoming.on("close", () => loseGuest(incoming));
      incoming.on("error", () => loseGuest(incoming));
      timeout = setTimeout(() => { if (!incoming.open) loseGuest(incoming); }, 20000);
    });
    roomPeer.on("disconnected", () => {
      if (peer === roomPeer && !channel?.open) elements["room-status"].textContent = "Signalisation déconnectée";
    });
    roomPeer.on("error", () => {
      if (peer === roomPeer && !channel?.open) elements["room-status"].textContent = "Service d’invitation indisponible";
    });
  } catch (error) {
    returnHome(error.message || "La partie en ligne n’a pas pu être créée.");
  }
}

function loseGuest(incoming) {
  if (channel !== incoming) return;
  clearConnection();
  elements["room-status"].textContent = "Invité hors ligne · réinvitation possible";
}

function shareGame() {
  if (!channel?.open || call) return;
  const canvas = elements["game-frame"].contentDocument?.querySelector("canvas");
  try {
    stream = captureVideo(canvas);
    if (gameSound) stream.addTrack(gameSound.destination.stream.getAudioTracks()[0].clone());
    call = peer.call(channel.peer, stream, { metadata: { protocol } });
    const incoming = channel;
    call.on("error", () => loseGuest(incoming));
    call.on("close", () => loseGuest(incoming));
  } catch {
    loseGuest(channel);
    elements["room-status"].textContent = "Le partage de l’écran du jeu a échoué.";
  }
}

function captureVideo(canvas) {
  const view = canvas.ownerDocument.defaultView;
  const video = canvas.captureStream(0);
  const [track] = video.getVideoTracks();
  if (typeof track?.requestFrame !== "function") {
    video.getTracks().forEach(item => item.stop());
    return canvas.captureStream(captureFps);
  }

  // A separate capture timer can skip a paint and wait for another timer tick.
  // Request frames on the game's refresh clock so the next paint can deliver them.
  const interval = 1000 / captureFps;
  let nextFrame = view.performance.now();
  let requestId;
  function capture(now) {
    if (now + 0.6 >= nextFrame) {
      track.requestFrame();
      const intervalsElapsed = Math.max(1, Math.floor((now - nextFrame) / interval) + 1);
      nextFrame += intervalsElapsed * interval;
    }
    requestId = view.requestAnimationFrame(capture);
  }

  if ("contentHint" in track) track.contentHint = "motion";
  requestId = view.requestAnimationFrame(capture);
  stopCapturing = () => view.cancelAnimationFrame(requestId);
  return video;
}

function joinGame() {
  if (!validRoom(invitation)) return;
  try {
    peer = peerFor();
    openGame("guest");
    elements["room-status"].textContent = "Connexion à l’hôte…";
    const roomPeer = peer;
    const lost = message => { if (peer === roomPeer) returnHome(message); };
    roomPeer.on("open", () => {
      if (peer !== roomPeer) return;
      channel = roomPeer.connect(invitation, { reliable: true, serialization: "json", metadata: { protocol } });
      channel.on("close", () => lost("La partie de l’hôte a été fermée ou la place est occupée."));
      channel.on("error", () => lost("Connexion à l’hôte interrompue."));
    });
    roomPeer.on("error", () => lost("Impossible de joindre l’hôte. Vérifie que sa partie est ouverte."));
    roomPeer.on("call", incoming => {
      if (peer !== roomPeer || incoming.peer !== invitation || incoming.metadata?.protocol !== protocol || call) {
        incoming.close();
        return;
      }
      call = incoming;
      incoming.on("stream", videoStream => {
        if (peer !== roomPeer) return;
        clearTimeout(timeout);
        const video = elements["guest-view"];
        video.srcObject = videoStream;
        const hasSound = () => videoStream.getAudioTracks().length > 0;
        const updateSoundButton = () => {
          elements.sound.hidden = !hasSound();
          elements.sound.textContent = video.muted ? "Activer le son" : "Couper le son";
        };
        videoStream.addEventListener("addtrack", updateSoundButton);
        video.muted = !hasSound();
        updateSoundButton();
        video.play().catch(() => {
          video.muted = true;
          updateSoundButton();
          video.play().catch(() => { elements["room-status"].textContent = "Clique sur l’écran pour démarrer."; });
        });
        video.focus();
        elements["room-status"].textContent = "J2 · Écran partagé";
      });
      incoming.on("close", () => lost("L’hôte a quitté la partie."));
      incoming.on("error", () => lost("Le partage vidéo a été interrompu."));
      incoming.answer();
    });
    timeout = setTimeout(() => lost("Connexion trop longue ou bloquée par le réseau."), 25000);
  } catch (error) {
    returnHome(error.message || "Impossible de se connecter.");
  }
}

function receiveInput(source, input) {
  if (source !== channel || !source.open || !Array.isArray(input) || input.length !== openInput.length) return;
  if (!input.every(Number.isFinite)) return;
  const buttons = input[4] & 15;
  pressed |= buttons & ~lastInput[4];
  lastInput = input.map((value, index) => index === 4 ? buttons : Math.max(-1, Math.min(1, value)));
  lastInputAt = performance.now();
}

const keyAxis = (negative, positive) =>
  Number(positive.some(key => keys.has(key))) - Number(negative.some(key => keys.has(key)));
function sendInput() {
  if (launch.mode !== "guest" || !channel?.open) return;
  if (document.hidden) {
    channel.send(openInput);
    return;
  }
  const pad = navigator.getGamepads?.().find(gamepad => gamepad?.mapping === "standard");
  const axis = (index, keyboard, deadzone) =>
    Math.abs(pad?.axes[index] ?? 0) > deadzone ? pad.axes[index] : keyboard;
  const buttons = [["KeyE", 3], ["KeyR", 2], ["KeyF", 0], ["KeyQ", 1]];
  const bits = buttons.reduce((mask, [key, index], i) =>
    mask | (keys.has(key) || pad?.buttons[index]?.pressed ? 1 << i : 0), 0);
  const dpadX = Number(!!pad?.buttons[15]?.pressed) - Number(!!pad?.buttons[14]?.pressed);
  const dpadY = Number(!!pad?.buttons[13]?.pressed) - Number(!!pad?.buttons[12]?.pressed);
  const keyX = keyAxis(["KeyA", "ArrowLeft"], ["KeyD", "ArrowRight"]) || dpadX;
  const keyY = keyAxis(["KeyW", "ArrowUp"], ["KeyS", "ArrowDown"]) || dpadY;
  const drivingWithPad = pad && Math.max(Math.abs(pad.axes[2]), Math.abs(pad.axes[1])) > .16;
  channel.send([
    axis(0, keyX, .2),
    axis(1, keyY, .2),
    axis(2, keyAxis(["KeyJ"], ["KeyL"]), .26),
    axis(3, keyAxis(["KeyI"], ["KeyK"]), .26),
    bits,
    drivingWithPad ? pad.axes[2] : keyX,
    drivingWithPad ? pad.axes[1] : keyY,
  ]);
}

const controls = new Set(["KeyW", "KeyA", "KeyS", "KeyD", "ArrowUp", "ArrowLeft", "ArrowDown",
  "ArrowRight", "KeyI", "KeyJ", "KeyK", "KeyL", "KeyE", "KeyR", "KeyF", "KeyQ"]);
for (const event of ["keydown", "keyup"]) {
  addEventListener(event, e => {
    if (launch.mode !== "guest" || elements.game.hidden || !controls.has(e.code)) return;
    e.preventDefault();
    if (event === "keydown") keys.add(e.code);
    else keys.delete(e.code);
    sendInput();
  });
}
addEventListener("blur", () => { keys.clear(); sendInput(); });
addEventListener("pagehide", () => peer?.destroy());
setInterval(sendInput, 33);

elements["start-form"].addEventListener("submit", event => {
  event.preventDefault();
  startSelectedGame(new FormData(elements["start-form"]).get("layout"));
});

function startSelectedGame(selection) {
  if (selection === "endurance") {
    if (pickerMode === "host") hostGame(defaultLayout, "", "endurance");
    else {
      if (paused && !confirm(launch.activity === "endurance" ? "Remplacer la course en cours ?" :
        "Mettre fin à la partie d’atelier ouverte ? Ta sauvegarde d’atelier reste disponible.")) return;
      openGame("solo", defaultLayout, "", "endurance");
    }
    return;
  }
  if (pickerMode === "solo" && paused && launch.activity === "endurance" &&
      !confirm("Terminer la course en cours pour ouvrir un garage ?")) return;
  if ((loadSave(pickerMode) || (pickerMode === "solo" && paused && launch.activity === "workshop")) &&
      !confirm("Remplacer la sauvegarde de cette partie ?")) return;
  if (pickerMode === "host") hostGame(Number(selection));
  else openGame("solo", Number(selection));
}
elements["new-game"].addEventListener("click", () => openPicker("solo"));
elements["multiplayer-button"].addEventListener("click", () => showScreen("multiplayer"));
elements["options-button"].addEventListener("click", () => showScreen("options"));
elements["notes-button"].addEventListener("click", () => showScreen("patch-notes"));
elements.back.addEventListener("click", () => {
  if (screen === "invited") clearInvitation();
  showScreen(screen === "map-screen" && pickerMode === "host" ? "multiplayer" : "home");
});
elements.resume.addEventListener("click", continueGame);
elements.host.addEventListener("click", () => openPicker("host"));
elements["resume-host"].addEventListener("click", () => hostGame(defaultLayout, loadSave("host")));
elements["join-form"].addEventListener("submit", event => {
  event.preventDefault();
  const room = new URL(elements["join-link"].value).hash.slice(1);
  const id = new URLSearchParams(room).get("join");
  if (!validRoom(id)) {
    elements.notice.textContent = "Ce lien d’invitation est invalide.";
    return;
  }
  invitation = id;
  if (paused && !confirm("Fermer le solo pour rejoindre ? La reprise solo se fera au dernier atelier libre sauvegardé.")) {
    invitation = null;
    return;
  }
  elements.join.disabled = false;
  joinGame();
});
elements.join.addEventListener("click", joinGame);
elements.exit.addEventListener("click", leaveGame);
elements.quality.value = settings.quality;
elements["show-fps"].checked = settings.showFps;
for (const name of ["quality", "show-fps"]) {
  elements[name].addEventListener("change", () => {
    settings = { quality: elements.quality.value, showFps: elements["show-fps"].checked };
    try { localStorage.setItem(settingsKey, JSON.stringify(settings)); } catch { /* Apply for this tab. */ }
    updateDisplay();
  });
}
elements.sound.addEventListener("click", () => {
  const video = elements["guest-view"];
  video.muted = !video.muted;
  elements.sound.textContent = video.muted ? "Activer le son" : "Couper le son";
  video.play().catch(() => {});
  video.focus();
});
elements["guest-view"].addEventListener("click", () => {
  elements["guest-view"].play().catch(() => {});
  elements["guest-view"].focus();
});
elements.invite.addEventListener("click", async () => {
  const field = elements["invite-url"];
  try {
    await navigator.clipboard.writeText(field.value);
    elements.invite.textContent = "Lien copié";
    setTimeout(() => { elements.invite.textContent = "Copier le lien"; }, 1800);
    elements["game-frame"].contentDocument?.querySelector("canvas")?.focus();
  } catch {
    field.hidden = false;
    field.focus();
    field.select();
  }
});

updateDisplay();
elements.join.disabled = !validRoom(invitation);
showScreen(invitation === null ? (location.hash === "#multiplayer" ? "multiplayer" : "home") : "invited", false,
  invitation !== null && !validRoom(invitation) ? "Ce lien d’invitation est invalide." : "");
