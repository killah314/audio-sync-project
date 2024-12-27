//IMPORTS
const express = require("express");
const http = require("http");
const mongoose = require("mongoose");
const Party = require('./models/Party');
const Track = require('./models/Track'); 
const { ObjectId } = mongoose.Types; // Import ObjectId
const cors = require('cors');
const axios = require('axios');
const YOUTUBE_API_KEY = 'AIzaSyCGwZ7Xq26YlJFrwKecLc3XuKmlvGIFRl8'; // Replace with your actual API key

// create a server
const app = express();
const port = process.env.PORT || 3000;
var server = http.createServer(app);
var io = require('socket.io')(server);

// middle ware
app.use(express.json());

// connect to mongodb
const DB = "mongodb+srv://bink:bink123@cluster0.x5jgi.mongodb.net/?retryWrites=true&w=majority&appName=Cluster0";

mongoose.connect(DB).then(() =>{
  console.log("Connected Successful!");
})
.catch((e) => {
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
                  party.isJoin = false; // Set isJoin to false once 3 players have joined
              }
                party = await party.save();
                io.to(partyId).emit('updateParty', party);
              } else if (party.players.length >= 3) {
                // If the player count is 3 or more, deny further joins
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
          // Find the party by partyId
          let party = await Party.findById(partyId);

          // Find the player to remove
          let playerIndex = party.players.findIndex((player) => player.socketID === socketID);
          if (playerIndex !== -1) {
              party.players.splice(playerIndex, 1); // Remove player from the array

              // If there are fewer than 3 players, set isJoin to true
              if (party.players.length < 3) {
                  party.isJoin = true;
              }

              // Save the updated party document
              await party.save();

              // Emit the updated party state
              io.to(partyId).emit('updateParty', party);

              // Notify the party leader that the player has been kicked out
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
          //console.log(trackId)

          if (trackIndex === -1) {
            socket.emit('trackDeleted', { message: 'Track not found' });
            return;
          }

          // Remove track from database
          party.tracks.splice(trackIndex, 1);
          await party.save();

          // Notify all clients about the updated party
          io.to(partyId).emit('updateParty', party);

          // Notify the party leader
          socket.emit('trackDeleted', { message: 'Track removed successfully' });
        } catch (err) {
          console.error('Error deleting track:', err);
        }
      });

      socket.on('deleteParty', async (data) => {
        const { partyId } = data;
        try {
          // Delete the party using async/await
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
          // Update the party and remove the player using async/await
          const result = await Party.findByIdAndUpdate(
            partyId,
            { $pull: { players: { socketID } } },
            { new: true } // Optionally return the updated party document
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
      
      
      
      

    //timer listener
    socket.on("timer", async ({playerId, partyId}) =>{
        let countDown = 5;
        let party = await Party.findById(partyId);
        let player = party.players.id(playerId);

        if (player.isPartyLeader){
            let timerId = setInterval(async () => {
                if(countDown>=0){
                    io.to(partyId).emit("timer", {
                    countDown,
                    msg:"Party Starting",
                });
                console.log(countDown);
                countDown--;
            }else {
                party.isJoin = false;
                party = await party.save();
                io.to(partyId).emit("updateParty", party);
                startPartyClock(partyId);
                clearInterval(timerId);
            }
        }, 1000)
        }
    });
    socket.on('playTrack', (data) => {
      currentTrack = data.url;  // Store the track URL
      isPlaying = true;
      io.emit('playTrack', { url: currentTrack });
    });
  
    // When a client emits 'pauseTrack', pause the track
    socket.on('pauseTrack', () => {
      isPlaying = false;
      io.emit('pauseTrack');
    });
});

const startPartyClock = async (partyId) => {
    let party = await Party.findById(partyId);
    party.startTime = new Date().getTime();
    party = await party.save();

    let time = 120;

    let timerId = setInterval(
        (function partyIntervalFunc() {
        if(time >= 0) {
            const timeFormat = calculateTime(time);
            io.to(partyId).emit("timer", {
                countDown: timeFormat,
                msg: "Time Remaining",
            });
            console.log(time);
            time--;
        }
        return partyIntervalFunc;
    })(),
    1000
    );
};


///////////////////////////////////////////////////////////////////////////////////////////////////
// CORS
app.post('/upload', async (req, res) => {
  console.log("Body received:", req.body);

  const { url, partyId } = req.body;

  // Validate input
  if (!url || !partyId) {
    return res.status(400).send('URL and Party ID are required');
  }

  try {
    // Extract the video ID from the URL
    const videoId = extractYouTubeVideoId(url);
    if (!videoId) {
      return res.status(400).send('Invalid YouTube URL');
    }

    // Fetch video details from YouTube API
    const videoDetails = await fetchYouTubeDetails(videoId);

    if (!videoDetails) {
      return res.status(500).send('Failed to fetch video details');
    }

    // Destructure the video details
    const { title, duration } = videoDetails;

    // Find the party
    let party = await Party.findById(partyId);
    if (!party) {
      return res.status(404).send("Party not found");
    }

    // Add a new track with fetched title and duration
    const newTrack = {
      title,
      url,
      duration,
    };

    party.tracks.push(newTrack); // Push the track to the party's tracks array
    await party.save(); // Save the updated party document

    // Emit updated party
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

// Utility function to extract YouTube video ID
function extractYouTubeVideoId(url) {
  const regex = /(?:youtu\.be\/|youtube\.com\/(?:.*[?&]v=|.*\/|embed\/|v\/))([^#&?]*).*/;
  const match = url.match(regex);
  return match && match[1] ? match[1] : null;
}

// Function to fetch video details using YouTube Data API
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

// Utility function to parse ISO 8601 duration
function parseISO8601Duration(duration) {
  const regex = /PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/;
  const match = duration.match(regex);
  const hours = match[1] ? `${match[1]}:` : '';
  const minutes = match[2] ? `${match[2].padStart(2, '0')}:` : '00:';
  const seconds = match[3] ? `${match[3].padStart(2, '0')}` : '00';
  return `${hours}${minutes}${seconds}`;
}


// API route to get all tracks of a party
app.get('/party/:partyId/tracks', async (req, res) => {
  const { partyId } = req.params;

  try {
    // Validate the partyId
    if (!ObjectId.isValid(partyId)) {
      return res.status(400).send('Invalid partyId format');
    }

    // Find the party and populate its tracks
    let party = await Party.findById(partyId).populate('tracks');
    if (!party) {
      return res.status(404).send('Party not found');
    }

    // Return the tracks associated with the party
    res.status(200).json({
      message: "Tracks fetched successfully",
      tracks: party.tracks,
    });
  } catch (err) {
    console.error("Error fetching tracks:", err);
    res.status(500).send("Error fetching tracks");
  }
});
///////////////////////////////////////////////////////////////////////////////////////////////////
