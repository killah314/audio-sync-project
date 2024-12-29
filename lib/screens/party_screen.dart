import 'dart:async';
import 'package:audio_sync_prototype/providers/party_state_provider.dart';
import 'package:audio_sync_prototype/utils/socket_client.dart';
import 'package:audio_sync_prototype/utils/socket_methods.dart';
import 'package:audio_sync_prototype/widgets/party_player_list.dart';
import 'package:audio_sync_prototype/widgets/party_track_list.dart';
import 'package:audio_sync_prototype/widgets/party_url_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';

class PartyScreen extends StatefulWidget {
  const PartyScreen({super.key});

  @override
  State<PartyScreen> createState() => _PartyScreenState();
}

class _PartyScreenState extends State<PartyScreen> {
  final SocketMethods _socketMethods = SocketMethods();
  final AudioPlayer _audioPlayer = AudioPlayer();

  String? _currentTrackUrl;
  int selectedTab = 0;
  Timer? _positionUpdateTimer;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  var playerMe = null;
  late PartyStateProvider? party;

  @override
  void initState() {
    super.initState();
    _socketMethods.updateParty(context);
    _socketMethods.trackAddedListener(context);
    _socketMethods.trackUpdateListener(context); // Ensure listener is active

    party = Provider.of<PartyStateProvider>(context, listen: false);
    findPlayerMe(party!);

    // Add listener for play/pause state changes
    _audioPlayer.playerStateStream.listen((state) {
      setState(() {
        Provider.of<PartyStateProvider>(context, listen: false).isPlaying = state
            .playing; // Sync the play/pause state from AudioPlayer to PartyStateProvider
      });
    });

    // Listen to the audio player's position stream to update the slider position
    _audioPlayer.positionStream.listen((newPosition) {
      setState(() {
        position = newPosition;
      });
      // Sync the position with the party state
      Provider.of<PartyStateProvider>(context, listen: false)
          .updateTrackPosition(newPosition);
    });

    // Ensure that the duration is set after loading the track
    _audioPlayer.durationStream.listen((newDuration) {
      setState(() {
        duration = newDuration ?? Duration.zero;
      });
    });
    _startPositionUpdateTimer();
  }

  findPlayerMe(PartyStateProvider party) {
    party.partyState['players'].forEach((player) {
      if (player['socketID'] == SocketClient.instance.socket!.id) {
        playerMe = player;
      }
    });
  }

  bool isHost() {
    findPlayerMe(party!);
    return playerMe['isPartyLeader'];
  }

  void _startPositionUpdateTimer() {
    _positionUpdateTimer =
        Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_audioPlayer.position != position) {
        setState(() {
          position = _audioPlayer.position;
        });
      }
    });
  }

  Future<void> playTrack(int index) async {
    final party = Provider.of<PartyStateProvider>(context, listen: false);
    final tracks = party.partyState['tracks'];

    if (index >= 0 && index < tracks.length) {
      String trackUrl = tracks[index]['url'];
      String trackTitle = tracks[index]['title']; // Get the track title
      String duration = tracks[index]['duration'];

      if (trackUrl.isEmpty) {
        print("Track URL is empty!");
        return;
      }

      // Print both the track title and URL
      print("Playing track: $trackTitle - $trackUrl - $duration");

      // Emit playTrack event to the server
      _socketMethods.playTrack(trackUrl, party.partyState['id'], index);

      setState(() {
        party.setPlaying(true);
        // Update the playing state in PartyStateProvider
        Provider.of<PartyStateProvider>(context, listen: false)
            .playTrack(index);
      });
    }
  }

  Future<void> resumeTrack(int index) async {
    final party = Provider.of<PartyStateProvider>(context, listen: false);
    final tracks = party.partyState['tracks'];

    if (index >= 0 && index < tracks.length) {
      String trackUrl = tracks[index]['url'];
      String trackTitle = tracks[index]['title']; // Get the track title

      if (trackUrl.isEmpty) {
        print("Track URL is empty!");
        return;
      }

      Duration currentPosition = _audioPlayer.position;

      // Print both the track title and URL
      print("Resuming track: $trackTitle - $trackUrl at $currentPosition");

      // Emit resumeTrack event to the server
      _socketMethods.resumeTrack(
          trackUrl, party.partyState['id'], currentPosition);

      setState(() {
        party.setPlaying(true);
        // Update the playing state in PartyStateProvider
        Provider.of<PartyStateProvider>(context, listen: false)
            .playTrack(index);
      });
    }
  }

  Future<void> pauseTrack(int index) async {
    final party = Provider.of<PartyStateProvider>(context, listen: false);
    final tracks = party.partyState['tracks'];

    Duration currentPosition = _audioPlayer.position;

    if (party.isPlaying && index >= 0 && index < tracks.length) {
      // Emit pauseTrack event to the server
      _socketMethods.pauseTrack(party.partyState['id']);

      setState(() {
        party.setPlaying(false);
        // Update the playing state in PartyStateProvider
        Provider.of<PartyStateProvider>(context, listen: false)
            .pauseTrack(index);
      });

      print(
          "Track paused: ${tracks[index]['title']} at $currentPosition"); // Log the paused track
    } else {
      print("No track is currently playing or invalid index.");
    }
  }

  // Play next track (circular)
  Future<void> nextTrack() async {
    final party = Provider.of<PartyStateProvider>(context, listen: false);
    final tracks = party.partyState['tracks'];

    if (tracks.isNotEmpty) {
      int nextIndex = ((party.currentTrackIndex + 1) % tracks.length)
          .toInt(); // Circular list logic

      setState(() {
        party.setPlaying(true); // Update party state after playing next track
        Provider.of<PartyStateProvider>(context, listen: false)
            .playTrack(nextIndex);
      });

      await playTrack(nextIndex); // Play the next track

      print("Next track playing: ${tracks[nextIndex]['title']}");
    } else {
      print("No tracks available to play.");
    }
  }

  // Play previous track (circular)
  Future<void> previousTrack() async {
    final party = Provider.of<PartyStateProvider>(context, listen: false);
    final tracks = party.partyState['tracks'];

    if (tracks.isNotEmpty) {
      int prevIndex =
          ((party.currentTrackIndex - 1 + tracks.length) % tracks.length)
              .toInt(); // Circular list logic

      setState(() {
        party.setPlaying(
            true); // Update party state after playing previous track
        Provider.of<PartyStateProvider>(context, listen: false)
            .playTrack(prevIndex);
      });

      await playTrack(prevIndex); // Play the previous track

      print("Previous track playing: ${tracks[prevIndex]['title']}");
    } else {
      print("No tracks available to play.");
    }
  }

  void _leaveParty(PartyStateProvider party) {
    final socketID = SocketClient.instance.socket!.id;
    final isPartyLeader = playerMe['isPartyLeader'];

    if (isPartyLeader) {
      // If the user is the party leader, delete the party from the database and disconnect
      SocketMethods().deleteParty(
          party.partyState['id']); // Emit the delete party event to the server

      // Optionally, show a message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Party has been deleted.")),
      );
    } else {
      // If the user is not the party leader, simply leave the party
      SocketMethods().leaveParty(
          socketID!, party.partyState['id']); // Emit leave party event

      // Optionally, show a message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You have left the party.")),
      );
    }

    // Navigate back to the home screen after leaving
    Navigator.pushReplacementNamed(context, '/');
  }

  @override
  Widget build(BuildContext context) {
    final party = Provider.of<PartyStateProvider>(context);
    final tracks = party.partyState['tracks'];
    final currentTrackIndex = party.currentTrackIndex;

    // Get the current track's title
    String trackTitle =
        currentTrackIndex >= 0 && currentTrackIndex < tracks.length
            ? tracks[currentTrackIndex]['title']
            : "No Track Playing";

    // Calculate remaining duration
    final remainingDuration = duration - position;
    print('AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA $duration');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Party Room"),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            onPressed: () => _leaveParty(party),
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Show the "Add URL" button and "Copy Party Code" input field at the top
            selectedTab == 1 // If Tracks tab is selected
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 600,
                      ),
                      child: PartyAddUrlButton(),
                    ),
                  )
                : const SizedBox.shrink(),
            selectedTab == 0 // If Players tab is selected
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 600,
                      ),
                      child: Column(
                        children: [
                          TextField(
                            readOnly: true,
                            onTap: () {
                              Clipboard.setData(ClipboardData(
                                text: party.partyState['id'],
                              )).then((_) {});
                            },
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Click to Copy Party Code',
                              hintStyle: const TextStyle(color: Colors.grey),
                              filled: true,
                              fillColor: Colors.black,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    const BorderSide(color: Colors.grey),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),

            // Display the appropriate list based on selected tab
            Expanded(
              child: Column(
                children: [
                  selectedTab == 0
                      ? Expanded(
                          child: Column(
                            children: [
                              // Player list
                              const Expanded(child: PartyPlayerList()),
                            ],
                          ),
                        )
                      : Expanded(
                          child: Column(
                            children: [
                              // Track list
                              const Expanded(child: PartyTrackList()),
                            ],
                          ),
                        ),
                ],
              ),
            ),
            // Tab buttons for Players and Tracks at the bottom (above audio controls)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(
                  border:
                      Border(top: BorderSide(color: Colors.white, width: 1))),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedTab = 0; // Switch to Players Tab
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        color: selectedTab == 0
                            ? Colors.white.withOpacity(0.2)
                            : Colors.transparent,
                        child: const Center(
                          child: Text(
                            'Players',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedTab = 1; // Switch to Tracks Tab
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        color: selectedTab == 1
                            ? Colors.white.withOpacity(0.2)
                            : Colors.transparent,
                        child: const Center(
                          child: Text(
                            'Tracks',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  trackTitle,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                  overflow: TextOverflow.fade, // Fading effect for long titles
                ),
              ),
            ),
            // Music slider to show the position of the current track
            Slider(
              value: position.inSeconds.toDouble(),
              min: 0.0,
              max: duration.inSeconds.toDouble(),
              onChanged: (double value) {
                final newPosition = Duration(seconds: value.toInt());
                setState(() {
                  position = Duration(seconds: value.toInt());
                });
                _audioPlayer.seek(position);
              },
            ),
            // Display the current position and remaining duration below the slider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(position),
                    style: const TextStyle(color: Colors.white),
                  ),
                  Text(
                    _formatDuration(remainingDuration),
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // Audio Player Buttons at the Bottom
      bottomNavigationBar: Container(
        color: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.skip_previous, color: Colors.white),
              iconSize: 40,
              padding: const EdgeInsets.all(16),
              onPressed: isHost()
                  ? previousTrack
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text("Only the host can control playback.")),
                      );
                    },
            ),
            IconButton(
              icon: Icon(
                party.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
              ),
              iconSize: 40,
              padding: const EdgeInsets.all(16),
              onPressed: isHost()
                  ? () async {
                      if (party.isPlaying) {
                        await pauseTrack(party.currentTrackIndex);
                      } else {
                        if (_audioPlayer.position == Duration.zero) {
                          await playTrack(party.currentTrackIndex);
                        } else {
                          await resumeTrack(party.currentTrackIndex);
                        }
                      }
                    }
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text("Only the host can control playback.")),
                      );
                    },
            ),
            IconButton(
              icon: const Icon(Icons.skip_next, color: Colors.white),
              iconSize: 40,
              padding: const EdgeInsets.all(16),
              onPressed: isHost()
                  ? nextTrack
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text("Only the host can control playback.")),
                      );
                    },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    // Format the duration to mm:ss
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _positionUpdateTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}

/*bottomNavigationBar: Container(
        color: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.skip_previous, color: Colors.white),
              iconSize: 40,
              padding: const EdgeInsets.all(16),
              onPressed: isHost()
                  ? previousTrack
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text("Only the host can control playback.")),
                      );
                    },
            ),
            IconButton(
              icon: Icon(
                party.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
              ),
              iconSize: 40,
              padding: const EdgeInsets.all(16),
              onPressed: isHost()
                  ? () async {
                      if (party.isPlaying) {
                        await pauseTrack(party.currentTrackIndex);
                      } else {
                        if (_audioPlayer.position == Duration.zero) {
                          await playTrack(party.currentTrackIndex);
                        } else {
                          await resumeTrack(party.currentTrackIndex);
                        }
                      }
                    }
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text("Only the host can control playback.")),
                      );
                    },
            ),
            IconButton(
              icon: const Icon(Icons.skip_next, color: Colors.white),
              iconSize: 40,
              padding: const EdgeInsets.all(16),
              onPressed: isHost()
                  ? nextTrack
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text("Only the host can control playback.")),
                      );
                    },
            ),
          ],
        ),
      ),*/
