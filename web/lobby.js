"use strict";

const elements = Object.fromEntries([...document.querySelectorAll("[id]")].map(el => [el.id, el]));
const saveKey = "garage-day.host.v1";
const protocol = 1;
const invitation = new URLSearchParams(location.hash.slice(1)).get("join");
const validRoom = id => /^gd-[0-9a-f]{32}$/.test(id ?? "");
const openInput = [0, 0, 0, 0, 0];
let launch = { mode: "solo", layout: 0, save: "" };
let peer, channel, call, stream, timeout;
let ready = false;
let lastInput = openInput;
let pressed = 0;
let lastInputAt = 0;
const keys = new Set();

function loadSave() {
  try { return localStorage.getItem(saveKey) || ""; }
  catch { return ""; }
}

window.GarageDay = {
  startInfo: () => JSON.stringify(launch),
  gameReady() {
    ready = true;
    elements["game-frame"].contentDocument?.querySelector("canvas")?.focus();
    if (launch.mode === "host") {
      showInvitation();
      if (channel?.open) shareGame();
    } else elements["room-status"].textContent = "";
  },
  guestInput() {
    const online = !!channel?.open && launch.mode === "host";
    const recent = online && performance.now() - lastInputAt < 600;
    const response = JSON.stringify([online, ...(recent ? lastInput : openInput), recent ? pressed : 0]);
    pressed = 0;
    return response;
  },
  storeSave(data) {
    if (launch.mode !== "host") return;
    try {
      if (data) localStorage.setItem(saveKey, data);
      else localStorage.removeItem(saveKey);
    } catch {
      elements["room-status"].textContent = "Le navigateur bloque la sauvegarde locale.";
    }
  },
};

function openGame(mode, layout = 0, save = "") {
  launch = { mode, layout, save };
  ready = false;
  elements.lobby.hidden = true;
  elements.game.hidden = false;
  elements.room.hidden = false;
  elements.invite.hidden = true;
  elements["invite-url"].hidden = true;
  elements["room-status"].textContent = "Chargement…";
  elements["guest-view"].hidden = mode !== "guest";
  elements["game-frame"].hidden = mode === "guest";
  if (mode !== "guest") elements["game-frame"].src = document.body.dataset.game;
}

function returnHome(message = "") {
  const oldPeer = peer;
  peer = undefined;
  clearTimeout(timeout);
  clearConnection();
  oldPeer?.destroy();
  ready = false;
  keys.clear();
  elements["game-frame"].removeAttribute("src");
  elements["guest-view"].srcObject = null;
  elements.game.hidden = true;
  elements.lobby.hidden = false;
  elements.notice.textContent = message;
  elements.resume.hidden = !loadSave();
  if (invitation !== null) elements.resume.hidden = true;
}

function clearConnection() {
  const oldChannel = channel;
  const oldCall = call;
  channel = call = undefined;
  oldChannel?.close();
  oldCall?.close();
  stream?.getTracks().forEach(track => track.stop());
  stream = undefined;
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

function hostGame(layout, save = "") {
  try {
    const id = "gd-" + crypto.randomUUID().replaceAll("-", "");
    peer = peerFor(id);
    openGame("host", layout, save);
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
    stream = canvas.captureStream(30);
    call = peer.call(channel.peer, stream, { metadata: { protocol } });
    const incoming = channel;
    call.on("error", () => loseGuest(incoming));
    call.on("close", () => loseGuest(incoming));
  } catch {
    loseGuest(channel);
    elements["room-status"].textContent = "Le partage de l’écran du jeu a échoué.";
  }
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
        video.play().catch(() => { elements["room-status"].textContent = "Clique sur l’écran pour démarrer."; });
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
  if (source !== channel || !source.open || !Array.isArray(input) || input.length !== 5) return;
  if (!input.every(Number.isFinite)) return;
  const buttons = input[4] & 15;
  pressed |= buttons & ~lastInput[4];
  lastInput = [...input.slice(0, 4).map(value => Math.max(-1, Math.min(1, value))), buttons];
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
  channel.send([
    axis(0, keyAxis(["KeyA", "ArrowLeft"], ["KeyD", "ArrowRight"]), .2),
    axis(1, keyAxis(["KeyW", "ArrowUp"], ["KeyS", "ArrowDown"]), .2),
    axis(2, keyAxis(["KeyJ"], ["KeyL"]), .26),
    axis(3, keyAxis(["KeyI"], ["KeyK"]), .26),
    bits,
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

const selectedLayout = () => Number(new FormData(elements["start-form"]).get("layout"));
elements["start-form"].addEventListener("submit", event => {
  event.preventDefault();
  if (invitation === null) openGame("solo", selectedLayout());
});
elements.host.addEventListener("click", () => {
  if (loadSave() && !confirm("Créer une nouvelle partie hébergée et remplacer la sauvegarde de l’hôte ?")) return;
  hostGame(selectedLayout());
});
elements.resume.addEventListener("click", () => hostGame(0, loadSave()));
elements.join.addEventListener("click", joinGame);
elements.exit.addEventListener("click", () => returnHome());
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

elements.resume.hidden = !loadSave();
if (invitation !== null) {
  elements["start-actions"].hidden = elements["layout-picker"].hidden = true;
  elements["join-actions"].hidden = false;
  elements["start-note"].textContent = "L’hôte doit garder le jeu ouvert. Vous partagez sa caméra et l’invité joue sans le son.";
  elements.join.disabled = !validRoom(invitation);
  if (!validRoom(invitation)) elements.notice.textContent = "Ce lien d’invitation est invalide.";
}
