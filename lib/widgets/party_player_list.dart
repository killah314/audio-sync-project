import 'package:audio_sync_prototype/providers/party_state_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audio_sync_prototype/utils/socket_client.dart';
import 'package:audio_sync_prototype/utils/socket_methods.dart';

class PartyPlayerList extends StatefulWidget {
  const PartyPlayerList({super.key});

  @override
  _PartyPlayerListState createState() => _PartyPlayerListState();
}

class _PartyPlayerListState extends State<PartyPlayerList> {
  @override
  void initState() {
    super.initState();

    // Listen for 'kickedFromParty' event when the player is kicked
    SocketClient.instance.socket!.on('kickedFromParty', (data) {
      // Show the snackbar with the kick message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message'])),
      );

      // Navigate to the home screen after being kicked
      Navigator.pushReplacementNamed(context, '/');
    });
  }

  @override
  void dispose() {
    super.dispose();

    // Clean up the socket listener when the widget is disposed
    SocketClient.instance.socket!.off('kickedFromParty');
  }

  @override
  Widget build(BuildContext context) {
    final partyData = Provider.of<PartyStateProvider>(context);
    var players = partyData.partyState['players'];
    var currentPlayer = players.firstWhere(
        (player) => player['socketID'] == SocketClient.instance.socket!.id);

    // Get the party leader status
    bool isPartyLeader = currentPlayer['isPartyLeader'];

    return ListView.builder(
      itemCount: players.length,
      itemBuilder: (context, index) {
        var player = players[index];

        // If the player is the current user, don't show the kick button
        if (player['socketID'] == SocketClient.instance.socket!.id) {
          return ListTile(
            title: Text(player['nickname']),
          );
        }

        return ListTile(
          title: Text(player['nickname']),
          trailing: isPartyLeader
              ? IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () {
                    _kickPlayer(player['socketID'], partyData);
                  },
                )
              : null,
        );
      },
    );
  }

  // Function to handle player kick
  void _kickPlayer(String socketID, PartyStateProvider partyData) async {
    // Emit the kick player event to the server
    SocketMethods().kickPlayer(socketID, partyData.partyState['id']);

    // Remove the player from the local player list
    partyData.removePlayer(socketID);

    // If there are fewer than 3 players, set isJoin back to true
    if (partyData.partyState['players'].length < 3) {
      partyData.updatePartyJoinStatus(true);
    }
  }
}
