//IMPORTS
const express = require("express");
const http = require("http");
const mongoose = require("mongoose");
const Party = require('./models/Party');
const Track = require('./models/Track'); 
const { ObjectId } = mongoose.Types; 
const cors = require('cors');
const axios = require('axios');
const YOUTUBE_API_KEY = 'AIzaSyCGwZ7Xq26YlJFrwKecLc3XuKmlvGIFRl8'; 
const ytdl = require('ytdl-core'); 


// create a server
const app = express();
const port = process.env.PORT || 3000;
var server = http.createServer(app);
var io = require('socket.io')(server);

// middle ware
app.use(express.json());

// connect to mongodb
const DB = "mongodb+srv://bink:bink123@cluster0.x5jgi.mongodb.net/?retryWrites=true&w=majority&appName=Cluster0";

mongoose.connect(DB).then(() => {
  console.log("Connected Successful!");
}).catch((e) => {
  console.log(e);
});

// listen to server
server.listen(port,"0.0.0.0", () =>{
  console.log(`Server started and running on port ${port}`);
})

// listening to socket.io events
io.on('connection', (socket) =>{    
    socket.on('create-party', async ({nickname})=> {
        try {
            let party = new Party();
            let player = {
                socketID: socket.id,
                nickname,
                isPartyLeader: true,
            };
            party.players.push(player);
            party = await party.save();

            const partyId = party._id.toString();
            socket.join(partyId);
            io.to(partyId).emit("updateParty", party);
        } catch (e) {
            console.log(e);
        }
    })

    socket.on('join-party', async ({nickname, partyId})=> {
        try {
            if(!partyId.match(/^[0-9a-fA-F]{24}$/)){
                socket.emit('notCorrectParty', "Please enter a valid party ID");
                return;
            }
            let party = await Party.findById(partyId);
            if(party.isJoin && party.players.length < 3){
                const id = party._id.toString();
                let player = {
                    socketID: socket.id,
                    nickname,
                };
                socket.join(id);
                party.players.push(player);
                if (party.players.length >= 3) {
                  party.isJoin = false; 
              }
                party = await party.save();
                io.to(partyId).emit('updateParty', party);
              } else if (party.players.length >= 3) {
 
                socket.emit('notCorrectParty', "The party is full, please try again later!");
            } else {
                socket.emit('notCorrectParty', "The party is in progress, please try again later!");
            }
        } catch (e) {
            console.log(e);
        }
    });

    socket.on('kick-player', async ({ socketID, partyId }) => {
      try {
          let party = await Party.findById(partyId);

          let playerIndex = party.players.findIndex((player) => player.socketID === socketID);
          if (playerIndex !== -1) {
              party.players.splice(playerIndex, 1); 

              if (party.players.length < 3) {
                  party.isJoin = true;
              }

              await party.save();

              io.to(partyId).emit('updateParty', party);

              socket.emit('playerKicked', { message: 'Player has been kicked' });
          }
      } catch (error) {
          console.error("Error kicking player:", error);
      }
    });

      socket.on('delete-track', async ({ trackId, partyId }) => {
        try {
          let party = await Party.findById(partyId);
          if (!party) {
            socket.emit('trackDeleted', { message: 'Party not found' });
            return;
          }

          let trackIndex = party.tracks.findIndex(
            (track) => track._id.toString() === trackId
          );

          if (trackIndex === -1) {
            socket.emit('trackDeleted', { message: 'Track not found' });
            return;
          }

          party.tracks.splice(trackIndex, 1);
          await party.save();

          io.to(partyId).emit('updateParty', party);

          socket.emit('trackDeleted', { message: 'Track removed successfully' });
        } catch (err) {
          console.error('Error deleting track:', err);
        }
      });

      socket.on('deleteParty', async (data) => {
        const { partyId } = data;
        try {
          const result = await Party.findByIdAndDelete(partyId);
      
          if (result) {
            console.log('Party deleted successfully');
          } else {
            console.log('Party not found');
          }
        } catch (err) {
          console.log('Error deleting party:', err);
        }
      });
      
      
      socket.on('leaveParty', async (data) => {
        const { socketID, partyId } = data;
        try {
          const result = await Party.findByIdAndUpdate(
            partyId,
            { $pull: { players: { socketID } } },
            { new: true } 
          );
      
          if (result) {
            console.log('Player removed successfully');
          } else {
            console.log('Party not found');
          }
        } catch (err) {
          console.log('Error removing player:', err);
        }
      });
      
    socket.on('playTrack', async (data) => {
      const { partyId, trackIndex } = data;
      console.log(`Broadcasting playTrack ${trackIndex} to party ${partyId}`);
      try {
          let party = await Party.findById(partyId);
          if (!party) {
            socket.emit('error', { message: 'Party not found' });
            return;
          }

          const track = party.tracks[trackIndex];
          console.log(track)
          if (!track || !track.url) {
            socket.emit('error', { message: 'Track not found or track URL is missing' });
            return;
          }

      io.to(partyId).emit('playTrack', {
        trackUrl: track.url,
        partyId: partyId,
        trackIndex: trackIndex,
      });
  } catch (err) {
    console.error('Error playing track:', err);
    socket.emit('error', { message: 'Error playing track' });
  }
});

    socket.on('pauseTrack', (data) => {
      const { partyId } = data;
      io.to(partyId).emit('pauseTrack', { isPlaying: false });
  });

    socket.on('nextTrack', (data) => {
      const { partyId, nextTrackIndex } = data;
      io.to(partyId).emit('nextTrack', { nextTrackIndex });
  });

    socket.on('previousTrack', (data) => {
      const { partyId, previousTrackIndex } = data;
      io.to(partyId).emit('previousTrack', { previousTrackIndex });
  });

 
});


// CORS
app.post('/upload', async (req, res) => {
  console.log("Body received:", req.body);

  const { url, partyId } = req.body;

  if (!url || !partyId) {
    return res.status(400).send('URL and Party ID are required');
  }

  try {
    const videoId = extractYouTubeVideoId(url);
    if (!videoId) {
      return res.status(400).send('Invalid YouTube URL');
    }

    const videoDetails = await fetchYouTubeDetails(videoId);

    if (!videoDetails) {
      return res.status(500).send('Failed to fetch video details');
    }

    const { title, duration } = videoDetails;

    let party = await Party.findById(partyId);
    if (!party) {
      return res.status(404).send("Party not found");
    }

    const newTrack = {
      title,
      url,
      duration,
    };

    party.tracks.push(newTrack); 
    await party.save(); 

    io.to(partyId).emit('updateParty', party);

    console.log("Track added with details:", newTrack);

    res.status(200).json({
      message: "Track added successfully",
      track: newTrack,
    });
  } catch (err) {
    console.error("Error:", err);
    res.status(500).send("Error adding track to party");
  }
});

function extractYouTubeVideoId(url) {
  const regex = /(?:youtu\.be\/|youtube\.com\/(?:.*[?&]v=|.*\/|embed\/|v\/))([^#&?]*).*/;
  const match = url.match(regex);
  return match && match[1] ? match[1] : null;
}

async function fetchYouTubeDetails(videoId) {
  try {
    const response = await axios.get(
      `https://www.googleapis.com/youtube/v3/videos?id=${videoId}&part=snippet,contentDetails&key=${YOUTUBE_API_KEY}`
    );

    const video = response.data.items[0];
    if (!video) return null;

    const title = video.snippet.title;
    const duration = parseISO8601Duration(video.contentDetails.duration);

    return { title, duration };
  } catch (err) {
    console.error("Error fetching video details:", err);
    return null;
  }
}

function parseISO8601Duration(duration) {
  const regex = /PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/;
  const match = duration.match(regex);
  const hours = match[1] ? `${match[1]}:` : '';
  const minutes = match[2] ? `${match[2].padStart(2, '0')}:` : '00:';
  const seconds = match[3] ? `${match[3].padStart(2, '0')}` : '00';
  return `${hours}${minutes}${seconds}`;
}


app.get('/party/:partyId/tracks', async (req, res) => {
  const { partyId } = req.params;

  try {
    if (!ObjectId.isValid(partyId)) {
      return res.status(400).send('Invalid partyId format');
    }

    let party = await Party.findById(partyId).populate('tracks');
    if (!party) {
      return res.status(404).send('Party not found');
    }

    res.status(200).json({
      message: "Tracks fetched successfully",
      tracks: party.tracks,
    });
  } catch (err) {
    console.error("Error fetching tracks:", err);
    res.status(500).send("Error fetching tracks");
  }
});

