// Shared camera + Face Landmarker loop, used by both the test page and the game.
// Privacy (target T7): frames are only read from memory. Nothing here saves or sends them.

import { FaceLandmarker, FilesetResolver } from "./vendor/vision_bundle.mjs";
import { createEmotionReader } from "./emotion.js";

// Turns a path into a full URL relative to THIS file, not to the page that loaded it.
// The game page lives one folder up, so plain "./models/..." would point to the wrong place.
const here = (path) => new URL(path, import.meta.url).href;

// Loads the WebAssembly runtime and the trained model. Tries the graphics card first;
// if that fails (some lab PCs have weak GPU support), falls back to the processor.
async function createLandmarker() {
  const vision = await FilesetResolver.forVisionTasks(here("./vendor/wasm"));
  const options = (delegate) => ({
    baseOptions: { modelAssetPath: here("./models/face_landmarker.task"), delegate },
    runningMode: "VIDEO",          // Frames arrive as a stream, so it can reuse the last result.
    numFaces: 1,                   // The game only cares about one player.
    outputFaceBlendshapes: true,   // The 52 movement scores. Off by default.
  });

  try {
    return await FaceLandmarker.createFromOptions(vision, options("GPU"));
  } catch (error) {
    console.warn("GPU face tracking failed, using CPU instead:", error);
    return FaceLandmarker.createFromOptions(vision, options("CPU"));
  }
}

// Asks the browser for the camera. This is what triggers the permission popup.
async function startCamera(video) {
  video.srcObject = await navigator.mediaDevices.getUserMedia({
    video: { width: 640, height: 480 },
    audio: false,
  });
  await video.play();
}

// Starts everything and calls the given functions as things happen:
//   onStatus(text)                  while loading ("loading model", "waiting for camera", "running")
//   onFrame({ categories, reading }) after each analysed frame; both are null when no face is found
// Returns { recalibrate } so the caller can restart calibration.
// Throws if the model or camera fails, so the caller decides how to show the error.
export async function startFaceTracking({ video, onStatus, onFrame }) {
  const reader = createEmotionReader();

  onStatus("loading model");
  const landmarker = await createLandmarker();
  onStatus("waiting for camera");
  await startCamera(video);
  onStatus("running");

  let lastVideoTime = -1;

  // Runs once per screen refresh, but only analyses frames the camera has updated.
  function tick() {
    if (video.currentTime !== lastVideoTime) {
      lastVideoTime = video.currentTime;
      const now = performance.now();
      const face = landmarker.detectForVideo(video, now).faceBlendshapes[0];

      if (face) {
        onFrame({ categories: face.categories, reading: reader.update(face.categories, now) });
      } else {
        onFrame({ categories: null, reading: null });
      }
    }
    requestAnimationFrame(tick);
  }
  tick();

  return { recalibrate: () => reader.recalibrate() };
}
