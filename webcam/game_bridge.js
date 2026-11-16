// Runs inside the exported game's page. Keeps the latest reading in window.faceReading,
// where Godot's FaceData autoload reads it with JavaScriptBridge.
//
// window.faceReading always looks like:
//   { status, faceFound, calibrating, label, confidence }
// status is one of: "loading model", "waiting for camera", "calibrating 40%",
// "tracking", "no face", "error: <message>". label is null until calibration finishes.

import { startFaceTracking } from "./face_tracker.js";

window.faceReading = {
  status: "loading model",
  faceFound: false,
  calibrating: false,
  label: null,
  confidence: 0,
};

// Changes only the given fields and keeps the rest (for example the last label).
function setReading(changes) {
  window.faceReading = { ...window.faceReading, ...changes };
}

// Called after every analysed frame.
function onFrame({ reading }) {
  if (!reading) {
    setReading({ status: "no face", faceFound: false });
  } else if (reading.calibrating) {
    setReading({
      status: `calibrating ${Math.round(reading.progress * 100)}%`,
      faceFound: true,
      calibrating: true,
    });
  } else {
    setReading({
      status: "tracking",
      faceFound: true,
      calibrating: false,
      label: reading.label,
      confidence: reading.confidence,
    });
  }
}

// The video must be in the page to play, but the player shouldn't see it.
// It's made invisible rather than display:none, because hidden videos may stop updating.
function createHiddenVideo() {
  const video = document.createElement("video");
  video.muted = true;
  video.playsInline = true;
  video.style.cssText = "position:fixed; width:1px; height:1px; opacity:0; pointer-events:none;";
  document.body.append(video);
  return video;
}

async function main() {
  try {
    const tracker = await startFaceTracking({
      video: createHiddenVideo(),
      onStatus: (text) => setReading({ status: text === "running" ? "no face" : text }),
      onFrame,
    });
    window.faceTracker = tracker; // lets Godot call window.faceTracker.recalibrate()
  } catch (error) {
    setReading({ status: `error: ${error.message}` });
    console.error(error);
  }
}

main();
