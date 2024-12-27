import 'package:audio_sync_prototype/providers/client_state_provider.dart';
import 'package:audio_sync_prototype/providers/party_state_provider.dart';
import 'package:audio_sync_prototype/utils/socket_client.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SocketMethods {
  final _socketClient = SocketClient.instance.socket!;
  bool _isPlaying = false;

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

// timer
  startTimer(playerId, partyId) {
    _socketClient.emit(
      'timer',
      {
        'playerId': playerId,
        'partyId': partyId,
      },
    );
  }

  updateTimer(BuildContext context) {
    final clientStateProvider =
        Provider.of<ClientStateProvider>(context, listen: false);
    _socketClient.on('timer', (data) {
      clientStateProvider.setClientState(data);
    });
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

  // playTrack now expects two arguments: trackUrl and partyId
  void playTrack(String trackUrl, String partyId) {
    // Emit the event with both parameters
    _socketClient.emit('playTrack', {'url': trackUrl, 'partyId': partyId});
  }

  // Pause the current track
  void pauseTrack() {
    _socketClient.emit('pauseTrack');
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
