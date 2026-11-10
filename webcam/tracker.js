// Connects the camera, Face Landmarker and the emotion reader, and draws the results.
// Privacy (target T7): frames are only read from memory. Nothing here saves or sends them.

import { FaceLandmarker, FilesetResolver } from "./vendor/vision_bundle.mjs";
import { createEmotionReader, THRESHOLD } from "./emotion.js";

const SCORES_TO_SHOW = 10;

const video = document.getElementById("camera");
const statusText = document.getElementById("status");
const labelText = document.getElementById("label");
const confidenceText = document.getElementById("confidence");
const evidencePanel = document.getElementById("evidence");
const scoresPanel = document.getElementById("scores");
const recalibrateButton = document.getElementById("recalibrate");

const reader = createEmotionReader();
recalibrateButton.addEventListener("click", () => reader.recalibrate());

// Loads the WebAssembly runtime and the trained model. Both are large, so this
// takes a moment, and "await" pauses here without freezing the page.
async function createLandmarker() {
  const vision = await FilesetResolver.forVisionTasks("./vendor/wasm");
  return FaceLandmarker.createFromOptions(vision, {
    baseOptions: { modelAssetPath: "./models/face_landmarker.task", delegate: "GPU" },
    runningMode: "VIDEO",          // Frames arrive as a stream, so it can reuse the last result.
    numFaces: 1,                   // The game only cares about one player.
    outputFaceBlendshapes: true,   // The 52 movement scores. Off by default.
  });
}

// Asks the browser for the camera. This is what triggers the permission popup.
async function startCamera() {
  video.srcObject = await navigator.mediaDevices.getUserMedia({
    video: { width: 640, height: 480 },
    audio: false,
  });
  await video.play();
}

// Builds one "name, bar, number" row. fraction (0 to 1) sets the bar length.
function makeBar(name, value, fraction) {
  const row = document.createElement("div");
  row.className = "row";

  const nameText = document.createElement("span");
  nameText.textContent = name;

  const track = document.createElement("div");
  track.className = "track";
  const fill = document.createElement("div");
  fill.className = "fill";
  fill.style.width = `${Math.min(1, fraction) * 100}%`;
  track.append(fill);

  const valueText = document.createElement("span");
  valueText.textContent = value.toFixed(2);

  row.append(nameText, track, valueText);
  return row;
}

// Shows the strongest raw movements, to see what the face is actually doing.
function showScores(categories) {
  const strongest = [...categories]
    .sort((a, b) => b.score - a.score)
    .slice(0, SCORES_TO_SHOW);
  scoresPanel.replaceChildren(
    ...strongest.map(({ categoryName, score }) => makeBar(categoryName, score, score)),
  );
}

// Shows the label, its confidence, and the evidence for each label.
function showReading(reading) {
  if (reading.calibrating) {
    statusText.textContent = `Calibrating: keep a relaxed face (${Math.round(reading.progress * 100)}%)`;
    labelText.textContent = "-";
    confidenceText.textContent = "";
    evidencePanel.replaceChildren();
    return;
  }

  statusText.textContent = "Reading your face";
  labelText.textContent = reading.label;
  confidenceText.textContent = `Confidence ${Math.round(reading.confidence * 100)}%`;
  // Bars are scaled so the threshold sits exactly halfway.
  evidencePanel.replaceChildren(
    ...Object.entries(reading.evidence).map(
      ([name, value]) => makeBar(name, value, value / (2 * THRESHOLD)),
    ),
  );
}

// Runs once per screen refresh, but only analyses frames the camera has updated.
function startLoop(landmarker) {
  let lastVideoTime = -1;

  function tick() {
    if (video.currentTime !== lastVideoTime) {
      lastVideoTime = video.currentTime;
      const now = performance.now();
      const result = landmarker.detectForVideo(video, now);
      const face = result.faceBlendshapes[0];

      if (face) {
        showScores(face.categories);
        showReading(reader.update(face.categories, now));
      } else {
        statusText.textContent = "No face found";
        scoresPanel.replaceChildren();
      }
    }
    requestAnimationFrame(tick);
  }

  tick();
}

async function main() {
  try {
    statusText.textContent = "Loading the face model...";
    const landmarker = await createLandmarker();
    statusText.textContent = "Waiting for camera permission...";
    await startCamera();
    startLoop(landmarker);
  } catch (error) {
    statusText.textContent = `Could not start: ${error.message}`;
    console.error(error);
  }
}

main();
