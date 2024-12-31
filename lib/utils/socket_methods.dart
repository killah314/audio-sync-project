import 'package:audio_sync_prototype/providers/party_state_provider.dart';
import 'package:audio_sync_prototype/utils/socket_client.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class SocketMethods {
  final _socketClient = SocketClient.instance.socket!;
  bool _isPlaying = false;
  late AudioPlayer _audioPlayer;
  String? _currentTrackUrl;

  SocketMethods() {
    _audioPlayer = AudioPlayer();
  }

  createParty(String nickname) {
    if (nickname.isNotEmpty) {
      _socketClient.emit('create-party', {
        'nickname': nickname,
      });
    }
  }

  joinParty(String partyId, String nickname) {
    if (nickname.isNotEmpty && partyId.isNotEmpty) {
      _socketClient.emit('join-party', {
        'nickname': nickname,
        'partyId': partyId,
      });
    }
  }

  updatePartyListener(BuildContext context) {
    _socketClient.on('updateParty', (data) {
      if (data != null) {
        print(data);

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
      if (data != null) {
        print(data);

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

  void trackAddedListener(BuildContext context) {
    _socketClient.on('trackAdded', (data) {
      if (data != null) {
        Provider.of<PartyStateProvider>(context, listen: false)
            .updatePartyState(
          id: data['id'],
          players: data['players'],
          isJoin: data['isJoin'],
          isOver: data['isOver'],
          tracks: data['tracks'],
        );
      }
    });
  }

  void kickPlayer(String socketID, String partyId) {
    SocketClient.instance.socket!.emit('kick-player', {
      'socketID': socketID,
      'partyId': partyId,
    });
  }

  void deleteTrack(String trackId, String partyId) {
    SocketClient.instance.socket!.emit('delete-track', {
      'trackId': trackId,
      'partyId': partyId,
    });
  }

  Future<void> playTrack(
      String trackUrl, String partyId, int trackIndex) async {
    try {
      final yt = YoutubeExplode();
      final videoId = _extractVideoId(trackUrl);

      if (videoId == null) {
        print('Invalid YouTube URL');
        return;
      }

      final streamManifest = await yt.videos.streamsClient.getManifest(videoId);
      final audioStream = streamManifest.audio.withHighestBitrate();
      final streamUrl = audioStream.url.toString();

      _socketClient.emit('playTrack', {
        'url': trackUrl,
        'partyId': partyId,
        'trackIndex': trackIndex,
      });
    } catch (e) {
      print('Error playing track: $e');
    }
  }

  Future<void> playplayTrack(
      String trackUrl, String partyId, int trackIndex) async {
    try {
      final yt = YoutubeExplode();
      final videoId = _extractVideoId(trackUrl);

      if (videoId == null) {
        print('Invalid YouTube URL');
        return;
      }

      final streamManifest = await yt.videos.streamsClient.getManifest(videoId);
      final audioStream = streamManifest.audio.withHighestBitrate();
      final streamUrl = audioStream.url.toString();

      if (_currentTrackUrl != streamUrl) {
        await _audioPlayer.setUrl(streamUrl);
        _currentTrackUrl = streamUrl;
      }

      if (!_audioPlayer.playing) {
        await _audioPlayer.play();
      }
    } catch (e) {
      print('Error playing track: $e');
    }
  }

  Future<void> resumeTrack(
      String trackUrl, String partyId, Duration currentPosition) async {
    try {
      final yt = YoutubeExplode();
      final videoId = _extractVideoId(trackUrl);

      if (videoId == null) {
        print('Invalid YouTube URL');
        return;
      }

      final streamManifest = await yt.videos.streamsClient.getManifest(videoId);
      final audioStream = streamManifest.audio.withHighestBitrate();
      final streamUrl = audioStream.url.toString();

      if (_currentTrackUrl != streamUrl) {
        await _audioPlayer.setUrl(streamUrl);
        _currentTrackUrl = streamUrl;
      }

      if (_audioPlayer.position != currentPosition) {
        await _audioPlayer.seek(currentPosition);
      }

      await _audioPlayer.play();

      _socketClient.emit('resumeTrack', {'url': trackUrl, 'partyId': partyId});
    } catch (e) {
      print('Error resuming track: $e');
    }
  }

  void pauseTrack(String partyId) {
    _audioPlayer.pause(); // Pause the audio
    _socketClient.emit('pauseTrack', {'partyId': partyId});
  }

  void nextTrack(String partyId, int nextTrackIndex) {
    _socketClient.emit(
        'nextTrack', {'partyId': partyId, 'nextTrackIndex': nextTrackIndex});
  }

  void previousTrack(String partyId, int previousTrackIndex) {
    _socketClient.emit('previousTrack',
        {'partyId': partyId, 'previousTrackIndex': previousTrackIndex});
  }

  void trackUpdateListener(BuildContext context) {
    _socketClient.on('playTrack', (data) {
      if (data != null) {
        final trackUrl = data['trackUrl'];
        final partyId = data['partyId'];
        final trackIndex = data['trackIndex'];

        if (!_isPlaying) {
          _isPlaying = true;

          final partyStateProvider =
              Provider.of<PartyStateProvider>(context, listen: false);
          partyStateProvider.updateTrackState(data['trackIndex'], true);
          playplayTrack(trackUrl, partyId, trackIndex);
          print(trackUrl);
          print(partyId);
          print(trackIndex);
        } else {
          print('Track is already playing, skipping...');
        }
      }
    });

    _socketClient.on('pauseTrack', (data) {
      if (data != null) {
        final partyStateProvider =
            Provider.of<PartyStateProvider>(context, listen: false);
        partyStateProvider.updateTrackState(
            partyStateProvider.currentTrackIndex, false);

        _audioPlayer.pause();
        _isPlaying = false;
      }
    });

    _socketClient.on('resumeTrack', (data) {
      if (data != null) {
        final trackUrl = data['url'];
        final currentPosition = Duration(milliseconds: data['currentPosition']);
        final partyId = data['partyId'];

        //resumeTrack(trackUrl, partyId, currentPosition);

        final partyStateProvider =
            Provider.of<PartyStateProvider>(context, listen: false);
        partyStateProvider.updateTrackState(data['trackIndex'], true);
      }
    });

    _socketClient.on('nextTrack', (data) {
      if (data != null) {
        final nextTrackIndex = data['nextTrackIndex'];

        final partyStateProvider =
            Provider.of<PartyStateProvider>(context, listen: false);
        partyStateProvider.updateTrackState(nextTrackIndex, true);

        _isPlaying = false;
      }
    });

    _socketClient.on('previousTrack', (data) {
      if (data != null) {
        final previousTrackIndex = data['previousTrackIndex'];

        final partyStateProvider =
            Provider.of<PartyStateProvider>(context, listen: false);
        partyStateProvider.updateTrackState(previousTrackIndex, true);

        _isPlaying = false;
      }
    });
  }

  String? _extractVideoId(String url) {
    final RegExp regExp = RegExp(
        r'(youtu\.be\/|youtube\.com\/(?:[^\/\n\s]+\/\S+\/|(?:v|e(?:mbed)?)\/|\S*?[?&]v=))([^"&?/\s]{11})');
    final match = regExp.firstMatch(url);
    return match?.group(2);
  }

  void deleteParty(String partyId) {
    SocketClient.instance.socket!.emit('deleteParty', {'partyId': partyId});
  }

  void leaveParty(String socketID, String partyId) {
    SocketClient.instance.socket!.emit('leaveParty', {
      'socketID': socketID,
      'partyId': partyId,
    });
  }

  void playerLeftListener(BuildContext context) {
    SocketClient.instance.socket!.on('playerLeft', (updatedPlayers) {
      final partyProvider =
          Provider.of<PartyStateProvider>(context, listen: false);
      partyProvider.updatePlayersList(updatedPlayers);
    });
  }
}
