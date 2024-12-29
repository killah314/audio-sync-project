import 'package:audio_sync_prototype/providers/party_state_provider.dart';
import 'package:audio_sync_prototype/utils/socket_client.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart'; // Import the just_audio package
import 'package:provider/provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class SocketMethods {
  final _socketClient = SocketClient.instance.socket!;
  bool _isPlaying = false;
  late AudioPlayer _audioPlayer; // Declare AudioPlayer instance
  String? _currentTrackUrl; // To store the current track URL

  // Create a constructor to initialize the AudioPlayer
  SocketMethods() {
    _audioPlayer = AudioPlayer();
  }

  // create party
  createParty(String nickname) {
    if (nickname.isNotEmpty) {
      _socketClient.emit('create-party', {
        'nickname': nickname,
      });
    }
  }

// join party
  joinParty(String partyId, String nickname) {
    if (nickname.isNotEmpty && partyId.isNotEmpty) {
      _socketClient.emit('join-party', {
        'nickname': nickname,
        'partyId': partyId,
      });
    }
  }

// players
  updatePartyListener(BuildContext context) {
    _socketClient.on('updateParty', (data) {
      // Ensure data is not null
      if (data != null) {
        print(data);

        // Check if data contains expected fields
        final partyStateProvider =
            Provider.of<PartyStateProvider>(context, listen: false);

        if (data['_id'] != null) {
          partyStateProvider.updatePartyState(
            id: data['_id'] ?? '',
            players: data['players'] ?? [],
            isJoin: data['isJoin'] ?? true,
            isOver: data['isOver'] ?? false,
            tracks: data['tracks'] ?? [],
          );
          // Safe navigation before pushing the route
          if (data['_id'].isNotEmpty && !_isPlaying) {
            Navigator.pushNamed(context, '/party-room');
            _isPlaying = true;
          }
        }
      }
    });
  }

  notCorrectPartyListener(BuildContext context) {
    _socketClient.on(
      'notCorrectParty',
      (data) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(data),
        ),
      ),
    );
  }

  updateParty(BuildContext context) {
    _socketClient.on('updateParty', (data) {
      // Ensure data is not null
      if (data != null) {
        print(data);

        // Check if data contains expected fields
        final partyStateProvider =
            Provider.of<PartyStateProvider>(context, listen: false);

        if (data['_id'] != null) {
          partyStateProvider.updatePartyState(
            id: data['_id'] ?? '',
            players: data['players'] ?? [],
            isJoin: data['isJoin'] ?? true,
            isOver: data['isOver'] ?? false,
            tracks: data['tracks'] ?? [],
          );
        }
      }
    });
  }

  // Track added listener
  void trackAddedListener(BuildContext context) {
    _socketClient.on('trackAdded', (data) {
      if (data != null) {
        Provider.of<PartyStateProvider>(context, listen: false)
            .updatePartyState(
          id: data['id'], // Extract 'id' from data
          players: data['players'], // Extract 'players' from data
          isJoin: data['isJoin'], // Extract 'isJoin' from data
          isOver: data['isOver'], // Extract 'isOver' from data
          tracks: data['tracks'], // Extract 'tracks' from data
        );
      }
    });
  }

  // New method to handle player kicking
  void kickPlayer(String socketID, String partyId) {
    SocketClient.instance.socket!.emit('kick-player', {
      'socketID': socketID,
      'partyId': partyId,
    });
  }

  // New method to handle track deleting
  void deleteTrack(String trackId, String partyId) {
    SocketClient.instance.socket!.emit('delete-track', {
      'trackId': trackId,
      'partyId': partyId,
    });
  }

  // Play track (YouTube audio playback logic)
  Future<void> playTrack(
      String trackUrl, String partyId, int trackIndex) async {
    try {
      final yt = YoutubeExplode();
      final videoId = _extractVideoId(trackUrl); // Extract the video ID

      if (videoId == null) {
        print('Invalid YouTube URL');
        return;
      }

      final streamManifest = await yt.videos.streamsClient.getManifest(videoId);
      final audioStream = streamManifest.audio.withHighestBitrate();
      final streamUrl = audioStream.url.toString(); // Get the audio URL

      _socketClient.emit('playTrack',
          {'url': trackUrl, 'partyId': partyId, 'trackIndex': trackIndex});

      // If the track URL is different from the current one, load and play the new track
      if (_currentTrackUrl != streamUrl) {
        await _audioPlayer.setUrl(streamUrl); // Set the audio URL
        _currentTrackUrl = streamUrl; // Update the current track URL
      }

      // Ensure the player is ready before calling play()
      if (!_audioPlayer.playing) {
        await _audioPlayer.play(); // Play the audio
      }
    } catch (e) {
      print('Error playing track: $e');
    }
  }

  // Resume track (YouTube audio playback logic)
  Future<void> resumeTrack(
      String trackUrl, String partyId, Duration currentPosition) async {
    try {
      final yt = YoutubeExplode();
      final videoId = _extractVideoId(trackUrl); // Extract the video ID

      if (videoId == null) {
        print('Invalid YouTube URL');
        return;
      }

      final streamManifest = await yt.videos.streamsClient.getManifest(videoId);
      final audioStream = streamManifest.audio.withHighestBitrate();
      final streamUrl = audioStream.url.toString(); // Get the audio URL

      // Ensure that the YouTube URL is different before setting it again
      if (_currentTrackUrl != streamUrl) {
        await _audioPlayer.setUrl(streamUrl); // Set the audio URL
        _currentTrackUrl = streamUrl; // Update the current track URL
      }

      // Seek to the current position if not playing
      if (_audioPlayer.position != currentPosition) {
        await _audioPlayer
            .seek(currentPosition); // Seek to the previous position
      }

      await _audioPlayer.play(); // Resume playing the audio

      _socketClient.emit('resumeTrack', {'url': trackUrl, 'partyId': partyId});
    } catch (e) {
      print('Error resuming track: $e');
    }
  }

  // Pause track
  void pauseTrack(String partyId) {
    _audioPlayer.pause(); // Pause the audio
    _socketClient.emit('pauseTrack', {'partyId': partyId});
  }

  // Next track
  void nextTrack(String partyId, int nextTrackIndex) {
    _socketClient.emit(
        'nextTrack', {'partyId': partyId, 'nextTrackIndex': nextTrackIndex});
  }

  // Previous track
  void previousTrack(String partyId, int previousTrackIndex) {
    _socketClient.emit('previousTrack',
        {'partyId': partyId, 'previousTrackIndex': previousTrackIndex});
  }

  // Listen for play/pause/next/previous track events from the server
  void trackUpdateListener(BuildContext context) {
    // Listen for playTrack event
    _socketClient.on('playTrack', (data) {
      if (data != null) {
        final trackUrl = data['trackUrl']; // Check if trackUrl is non-null here
        final partyId = data['partyId']; // Check if partyId is non-null here
        final trackIndex = data['trackIndex'];

        // Only play the track if it's not already playing
        if (!_isPlaying) {
          // Mark that the track is playing
          _isPlaying = true;

          // Continue processing if data is valid
          final partyStateProvider =
              Provider.of<PartyStateProvider>(context, listen: false);
          partyStateProvider.updateTrackState(data['trackIndex'], true);
          playTrack(trackUrl, partyId, trackIndex);
          print(trackUrl);
          print(partyId);
          print(trackIndex);
        } else {
          print('Track is already playing, skipping...');
        }
      }
    });

    // Listen for pauseTrack event
    _socketClient.on('pauseTrack', (data) {
      if (data != null) {
        final partyStateProvider =
            Provider.of<PartyStateProvider>(context, listen: false);
        partyStateProvider.updateTrackState(
            partyStateProvider.currentTrackIndex,
            false); // Update play state to false

        // Pause the track locally
        _audioPlayer.pause();
        _isPlaying = false; // Mark as not playing
      }
    });

    // Listen for resumeTrack event
    _socketClient.on('resumeTrack', (data) {
      if (data != null) {
        final trackUrl = data['url']; // Get the track URL
        final currentPosition = Duration(
            milliseconds: data['currentPosition']); // Get the current position
        final partyId = data['partyId']; // Get the party ID

        // Resume the track locally from the stored position
        //resumeTrack(trackUrl, partyId, currentPosition);

        // Update the track state in the party state provider
        final partyStateProvider =
            Provider.of<PartyStateProvider>(context, listen: false);
        partyStateProvider.updateTrackState(
            data['trackIndex'], true); // Update play state to true
      }
    });

    // Listen for nextTrack event
    _socketClient.on('nextTrack', (data) {
      if (data != null) {
        final nextTrackIndex =
            data['nextTrackIndex']; // Get the next track index

        // Update the track state in the party state provider
        final partyStateProvider =
            Provider.of<PartyStateProvider>(context, listen: false);
        partyStateProvider.updateTrackState(
            nextTrackIndex, true); // Update track index to next

        _isPlaying = false;
      }
    });

    // Listen for previousTrack event
    _socketClient.on('previousTrack', (data) {
      if (data != null) {
        final previousTrackIndex =
            data['previousTrackIndex']; // Get the previous track index

        // Update the track state in the party state provider
        final partyStateProvider =
            Provider.of<PartyStateProvider>(context, listen: false);
        partyStateProvider.updateTrackState(
            previousTrackIndex, true); // Update track index to previous

        _isPlaying = false;
      }
    });
  }

  // Helper method to extract video ID from YouTube URL
  String? _extractVideoId(String url) {
    final RegExp regExp = RegExp(
        r'(youtu\.be\/|youtube\.com\/(?:[^\/\n\s]+\/\S+\/|(?:v|e(?:mbed)?)\/|\S*?[?&]v=))([^"&?/\s]{11})');
    final match = regExp.firstMatch(url);
    return match?.group(2); // Extracts the video ID from the URL
  }

  // Function to delete the party (called when the party leader leaves)
  void deleteParty(String partyId) {
    SocketClient.instance.socket!.emit('deleteParty', {'partyId': partyId});
  }

  // Function to handle leaving the party
  void leaveParty(String socketID, String partyId) {
    SocketClient.instance.socket!.emit('leaveParty', {
      'socketID': socketID,
      'partyId': partyId,
    });
  }
}
