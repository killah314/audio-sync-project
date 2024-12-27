import 'package:audio_sync_prototype/providers/party_state_provider.dart';
import 'package:audio_sync_prototype/utils/socket_client.dart';
import 'package:audio_sync_prototype/utils/socket_methods.dart';
import 'package:audio_sync_prototype/widgets/custom_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PartyStartButton extends StatefulWidget {
  const PartyStartButton({super.key});

  @override
  State<PartyStartButton> createState() => _PartyStartButtonState();
}

class _PartyStartButtonState extends State<PartyStartButton> {
  final SocketMethods _socketMethods = SocketMethods();
  var playerMe = null;
  bool isBtn = true;
  late PartyStateProvider? party;

  @override
  void initState() {
    super.initState();
    party = Provider.of<PartyStateProvider>(context, listen: false);
    findPlayerMe(party!);
  }

  findPlayerMe(PartyStateProvider party) {
    party.partyState['players'].forEach((player) {
      if (player['socketID'] == SocketClient.instance.socket!.id) {
        playerMe = player;
      }
    });
  }

  handleStart(PartyStateProvider party) {
    _socketMethods.startTimer(playerMe['_id'], party.partyState['id']);
    setState(() {
      isBtn = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final partyData = Provider.of<PartyStateProvider>(context);

    return playerMe['isPartyLeader'] && isBtn
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              CustomButton(
                text: 'START',
                onTap: () => handleStart(partyData),
              ),
            ],
          )
        : const SizedBox(); // Display nothing if not party leader
  }
}
