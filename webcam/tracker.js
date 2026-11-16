// The test page: draws the label, the evidence and the raw scores so we can tune emotion.js.
// The camera and model loop itself lives in face_tracker.js, shared with the game.

import { startFaceTracking } from "./face_tracker.js";
import { THRESHOLD } from "./emotion.js";

const SCORES_TO_SHOW = 10;

const video = document.getElementById("camera");
const statusText = document.getElementById("status");
const labelText = document.getElementById("label");
const confidenceText = document.getElementById("confidence");
const evidencePanel = document.getElementById("evidence");
const scoresPanel = document.getElementById("scores");
const recalibrateButton = document.getElementById("recalibrate");

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

// Called after every analysed frame.
function onFrame({ categories, reading }) {
  if (!reading) {
    statusText.textContent = "No face found";
    scoresPanel.replaceChildren();
    return;
  }
  showScores(categories);
  showReading(reading);
}

async function main() {
  try {
    const tracker = await startFaceTracking({
      video,
      onStatus: (text) => { statusText.textContent = text; },
      onFrame,
    });
    recalibrateButton.addEventListener("click", tracker.recalibrate);
  } catch (error) {
    statusText.textContent = `Could not start: ${error.message}`;
    console.error(error);
  }
}

main();
