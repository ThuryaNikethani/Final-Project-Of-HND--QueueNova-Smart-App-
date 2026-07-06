// Local, offline image moderation — no cloud account, no API key, no billing.
// Uses NSFWJS (open-source, MIT licensed) running entirely on this server;
// images never leave the machine. Model weights are downloaded once from
// NSFWJS's public CDN the first time the server starts, then kept in memory.

const tf = require('@tensorflow/tfjs');
const nsfwjs = require('nsfwjs');
const { Jimp } = require('jimp');

const FLAGGED_CLASSES = new Set(['Porn', 'Hentai', 'Sexy']);
const THRESHOLD = 0.7;

let _modelPromise = null;

function getModel() {
  if (!_modelPromise) {
    _modelPromise = nsfwjs.load().then((model) => {
      console.log('✅ Image moderation model loaded (NSFWJS)');
      return model;
    });
  }
  return _modelPromise;
}

async function bufferToTensor(buffer) {
  const image = await Jimp.read(buffer);
  const { width, height, data } = image.bitmap; // RGBA buffer
  const numPixels = width * height;
  const values = new Int32Array(numPixels * 3);
  for (let i = 0; i < numPixels; i++) {
    values[i * 3] = data[i * 4];
    values[i * 3 + 1] = data[i * 4 + 1];
    values[i * 3 + 2] = data[i * 4 + 2];
  }
  return tf.tensor3d(values, [height, width, 3], 'int32');
}

/// Classifies image bytes and returns { safe, reasons, predictions }.
async function moderateImage(buffer) {
  const model = await getModel();
  const tensor = await bufferToTensor(buffer);
  try {
    const predictions = await model.classify(tensor);
    const reasons = predictions
      .filter((p) => FLAGGED_CLASSES.has(p.className) && p.probability >= THRESHOLD)
      .map((p) => p.className.toLowerCase());
    return { safe: reasons.length === 0, reasons, predictions };
  } finally {
    tensor.dispose();
  }
}

module.exports = { moderateImage, getModel };
