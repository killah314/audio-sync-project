const mongoose = require('mongoose');

const playerSchema = new mongoose.Schema({
    nickname: {
        type: String
    },
    currentTimeStamp:{
        type: Number,
        default: 0,
    },
    currentTrack:{
        type: Number,
        default: 0,
    },
    socketID: {
        type: String, 
    },
    isPartyLeader: {
        type: Boolean,
        default: false,
    },
});

module.exports = playerSchema;