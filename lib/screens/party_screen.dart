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
    _socketMethods.trackUpdateListener(context);
    _socketMethods.playerLeftListener(context); // Add this

    party = Provider.of<PartyStateProvider>(context, listen: false);
    findPlayerMe(party!);

    _audioPlayer.playerStateStream.listen((state) {
      setState(() {
        Provider.of<PartyStateProvider>(context, listen: false).isPlaying =
            state.playing;
      });
    });

    _audioPlayer.positionStream.listen((newPosition) {
      setState(() {
        position = newPosition;
      });
      // ignore: use_build_context_synchronously
      Provider.of<PartyStateProvider>(context, listen: false)
          .updateTrackPosition(newPosition);
    });

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
      String trackTitle = tracks[index]['title'];
      String duration = tracks[index]['duration'];

      if (trackUrl.isEmpty) {
        print("Track URL is empty!");
        return;
      }

      print("Playing track: $trackTitle - $trackUrl - $duration");

      _socketMethods.playTrack(trackUrl, party.partyState['id'], index);

      setState(() {
        party.setPlaying(true);
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
      String trackTitle = tracks[index]['title'];

      if (trackUrl.isEmpty) {
        print("Track URL is empty!");
        return;
      }

      Duration currentPosition = _audioPlayer.position;

      print("Resuming track: $trackTitle - $trackUrl at $currentPosition");

      _socketMethods.resumeTrack(
          trackUrl, party.partyState['id'], currentPosition);

      setState(() {
        party.setPlaying(true);
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
      _socketMethods.pauseTrack(party.partyState['id']);

      setState(() {
        party.setPlaying(false);
        Provider.of<PartyStateProvider>(context, listen: false)
            .pauseTrack(index);
      });

      print("Track paused: ${tracks[index]['title']} at $currentPosition");
    } else {
      print("No track is currently playing or invalid index.");
    }
  }

  Future<void> nextTrack() async {
    final party = Provider.of<PartyStateProvider>(context, listen: false);
    final tracks = party.partyState['tracks'];

    if (tracks.isNotEmpty) {
      int nextIndex = ((party.currentTrackIndex + 1) % tracks.length).toInt();

      setState(() {
        party.setPlaying(true);
        Provider.of<PartyStateProvider>(context, listen: false)
            .playTrack(nextIndex);
      });

      await playTrack(nextIndex);

      print("Next track playing: ${tracks[nextIndex]['title']}");
    } else {
      print("No tracks available to play.");
    }
  }

  Future<void> previousTrack() async {
    final party = Provider.of<PartyStateProvider>(context, listen: false);
    final tracks = party.partyState['tracks'];

    if (tracks.isNotEmpty) {
      int prevIndex =
          ((party.currentTrackIndex - 1 + tracks.length) % tracks.length)
              .toInt();

      setState(() {
        party.setPlaying(true);
        Provider.of<PartyStateProvider>(context, listen: false)
            .playTrack(prevIndex);
      });

      await playTrack(prevIndex);

      print("Previous track playing: ${tracks[prevIndex]['title']}");
    } else {
      print("No tracks available to play.");
    }
  }

  void _leaveParty(PartyStateProvider party) {
    final socketID = SocketClient.instance.socket!.id;
    final isPartyLeader = playerMe['isPartyLeader'];

    if (isPartyLeader) {
      SocketMethods().deleteParty(party.partyState['id']);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Party has been deleted.")),
      );
    } else {
      SocketMethods().leaveParty(socketID!, party.partyState['id']);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You have left the party.")),
      );
    }

    // Update the local party state
    setState(() {
      party.partyState['players']
          .removeWhere((player) => player['socketID'] == socketID);
    });

    Navigator.pushReplacementNamed(context, '/');
  }

  @override
  Widget build(BuildContext context) {
    final party = Provider.of<PartyStateProvider>(context);
    final tracks = party.partyState['tracks'];
    final currentTrackIndex = party.currentTrackIndex;

    String trackTitle =
        currentTrackIndex >= 0 && currentTrackIndex < tracks.length
            ? tracks[currentTrackIndex]['title']
            : "No Track Playing";

    final remainingDuration = duration - position;

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
            selectedTab == 1
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
            selectedTab == 0
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
            Expanded(
              child: Column(
                children: [
                  selectedTab == 0
                      ? const Expanded(
                          child: Column(
                            children: [
                              Expanded(child: PartyPlayerList()),
                            ],
                          ),
                        )
                      : const Expanded(
                          child: Column(
                            children: [
                              Expanded(child: PartyTrackList()),
                            ],
                          ),
                        ),
                ],
              ),
            ),
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
                          selectedTab = 0;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        color: selectedTab == 0
                            // ignore: deprecated_member_use
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
                          selectedTab = 1;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        color: selectedTab == 1
                            // ignore: deprecated_member_use
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
                  overflow: TextOverflow.fade,
                ),
              ),
            ),
            /*Slider(
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
            ),*/
          ],
        ),
      ),
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
