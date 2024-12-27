import 'package:audio_sync_prototype/providers/party_state_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audio_sync_prototype/utils/socket_client.dart';
import 'package:audio_sync_prototype/utils/socket_methods.dart';

class PartyTrackList extends StatefulWidget {
  const PartyTrackList({super.key});

  @override
  _PartyTrackListState createState() => _PartyTrackListState();
}

class _PartyTrackListState extends State<PartyTrackList> {
  @override
  void initState() {
    super.initState();

    // Listen for 'trackDeleted' event when a track is removed
    SocketClient.instance.socket!.on('trackDeleted', (data) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message'])),
      );
    });
  }

  @override
  void dispose() {
    super.dispose();

    // Clean up the socket listener when the widget is disposed
    SocketClient.instance.socket!.off('trackDeleted');
  }

  @override
  Widget build(BuildContext context) {
    final partyData = Provider.of<PartyStateProvider>(context);
    // Get the party leader status
    var players = partyData.partyState['players'];
    var currentPlayer = players.firstWhere(
        (player) => player['socketID'] == SocketClient.instance.socket!.id);
    bool isPartyLeader = currentPlayer['isPartyLeader'];

    return ListView.builder(
      shrinkWrap: true,
      itemCount: partyData.partyState['tracks'].length,
      itemBuilder: (context, index) {
        var track = partyData.partyState['tracks'][index];
        return Padding(
          padding: const EdgeInsets.symmetric(
              vertical: 2.0), // Reduce vertical spacing
          child: ListTile(
            contentPadding: EdgeInsets.zero, // Remove default padding
            title: Text(
              track['title'],
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              'Duration: ${track['duration']}',
              style: const TextStyle(color: Colors.white54),
            ),
            trailing: isPartyLeader
                ? IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      _deleteTrack(track['_id'].toString(), partyData);
                    },
                  )
                : null,
          ),
        );
      },
    );
  }

  // Function to handle track deletion
  void _deleteTrack(String trackId, PartyStateProvider partyData) async {
    // Emit the delete track event to the server
    SocketMethods().deleteTrack(trackId, partyData.partyState['id']);

    // Remove the track from the local track list
    partyData.removeTrack(trackId);
  }
}
