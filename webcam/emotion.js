// Turns Face Landmarker's 52 movement scores into one label: calm, nervous, afraid or angry.
// No camera or page code lives here, so the same logic can be reused inside the game.

// Which movements count as evidence for each label, and how much each one counts.
// Based on the facial movements psychologists associate with each emotion.
// Calm has no list: it is what's left when nothing else is strong enough.
const SIGNALS = {
  nervous: {
    mouthPressLeft: 1, mouthPressRight: 1,   // lips pressed together
    mouthRollLower: 1, mouthRollUpper: 0.5,  // lips pulled in
    browInnerUp: 0.5,                        // slight worried brow
  },
  afraid: {
    browInnerUp: 1,                          // inner brows pulled up
    eyeWideLeft: 1, eyeWideRight: 1,         // eyes opened wide
    mouthStretchLeft: 0.5, mouthStretchRight: 0.5,
  },
  angry: {
    browDownLeft: 1, browDownRight: 1,       // brows pulled down
    eyeSquintLeft: 0.5, eyeSquintRight: 0.5,
    noseSneerLeft: 0.5, noseSneerRight: 0.5,
  },
};

// Starting values to tune by testing on real faces.
const CALIBRATION_MS = 3000; // how long to record the player's relaxed face
const SMOOTHING_MS = 400;    // roughly how long a change must last to count
const THRESHOLD = 0.15;      // evidence needed before a label beats calm

// Creates a reader that remembers this player's relaxed face and recent readings.
// Each call to createEmotionReader() gets its own separate memory (a "closure").
export function createEmotionReader() {
  let baseline = null;         // average relaxed score for each movement
  let baselineSums = {};
  let baselineFrames = 0;
  let calibrationStart = null;
  let lastTime = null;
  let smoothed = { nervous: 0, afraid: 0, angry: 0 };

  // MediaPipe gives a list of {categoryName, score}. A lookup by name is easier to use.
  function toScoreMap(categories) {
    const scores = {};
    for (const { categoryName, score } of categories) {
      scores[categoryName] = score;
    }
    return scores;
  }

  // Adds one frame to the running totals; after CALIBRATION_MS, turns the totals into averages.
  // Returns how far through calibration we are, from 0 to 1.
  function calibrate(scores, timeMs) {
    if (calibrationStart === null) calibrationStart = timeMs;

    for (const [name, score] of Object.entries(scores)) {
      baselineSums[name] = (baselineSums[name] ?? 0) + score;
    }
    baselineFrames += 1;

    const progress = Math.min(1, (timeMs - calibrationStart) / CALIBRATION_MS);
    if (progress === 1) {
      baseline = {};
      for (const [name, sum] of Object.entries(baselineSums)) {
        baseline[name] = sum / baselineFrames;
      }
      lastTime = timeMs;
    }
    return progress;
  }

  // Weighted average of how far each listed movement has risen above the relaxed face.
  // Movements below the baseline count as 0, not negative.
  function evidenceFor(weights, scores) {
    let total = 0;
    let weightSum = 0;
    for (const [name, weight] of Object.entries(weights)) {
      total += weight * Math.max(0, (scores[name] ?? 0) - (baseline[name] ?? 0));
      weightSum += weight;
    }
    return total / weightSum;
  }

  // Call once per analysed frame. Returns the current reading.
  function update(categories, timeMs) {
    const scores = toScoreMap(categories);

    if (baseline === null) {
      return { calibrating: true, progress: calibrate(scores, timeMs) };
    }

    // How far to move toward the new value. Depends on the time since the last frame,
    // so smoothing behaves the same at 15 or 60 frames per second.
    const blend = 1 - Math.exp(-(timeMs - lastTime) / SMOOTHING_MS);
    lastTime = timeMs;

    for (const [label, weights] of Object.entries(SIGNALS)) {
      smoothed[label] += blend * (evidenceFor(weights, scores) - smoothed[label]);
    }

    return { calibrating: false, ...pickLabel(smoothed), evidence: { ...smoothed } };
  }

  // Forgets the relaxed face so the next 3 seconds are recorded again.
  function recalibrate() {
    baseline = null;
    baselineSums = {};
    baselineFrames = 0;
    calibrationStart = null;
    smoothed = { nervous: 0, afraid: 0, angry: 0 };
  }

  return { update, recalibrate };
}

// Chooses the label with the most evidence, or calm if none passes the threshold.
// Confidence is a 0 to 1 measure of signal strength, not a true probability.
function pickLabel(evidence) {
  let label = "calm";
  let strongest = 0;
  for (const [name, value] of Object.entries(evidence)) {
    if (value > strongest) {
      label = name;
      strongest = value;
    }
  }

  if (strongest < THRESHOLD) {
    return { label: "calm", confidence: 1 - strongest / THRESHOLD };
  }
  return { label, confidence: Math.min(1, strongest / (2 * THRESHOLD)) };
}

export { THRESHOLD };
