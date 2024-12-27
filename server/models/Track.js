const mongoose = require('mongoose');

const trackSchema = new mongoose.Schema({
  title: { type: String, required: true },
  url: { 
    type: String, 
    required: true, 
    match: /^https:\/\/(?:www\.)?(youtube\.com\/.+|youtu\.be\/.+)/ // Validate YouTube URL format
  },
  duration: { 
    type: String, 
    default: 'N/A',
    match: /^(\d{2,}:\d{2}:\d{2}|\d{2}:\d{2})$/ // Matches HH:MM:SS or MM:SS
  },
}, );

module.exports = trackSchema;
