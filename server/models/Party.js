const mongoose = require('mongoose');
const playerSchema = require('./Player');
const trackSchema = require('./Track'); // Import the Track schema

const partySchema = new mongoose.Schema({
  // Embed the track schema directly in the party schema
  tracks: [trackSchema],  // This embeds the track schema as an array of tracks
  players: [playerSchema],
  isJoin: {
    type: Boolean,
    default: true,
  },
  isOver: {
    type: Boolean,
    default: false,
  },
});

module.exports = mongoose.model('Party', partySchema); // Create the Party model
