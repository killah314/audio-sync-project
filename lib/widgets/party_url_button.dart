import 'package:audio_sync_prototype/providers/party_state_provider.dart';
import 'package:audio_sync_prototype/utils/socket_client.dart';
import 'package:audio_sync_prototype/utils/socket_methods.dart';
import 'package:audio_sync_prototype/widgets/custom_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

///////////////////////////////////////////////////////////////////////////////////////////////////
import 'dart:convert';
import 'package:http/http.dart' as http;
///////////////////////////////////////////////////////////////////////////////////////////////////

class PartyAddUrlButton extends StatefulWidget {
  const PartyAddUrlButton({super.key});

  @override
  State<PartyAddUrlButton> createState() => _PartyAddUrlButtonState();
}

class _PartyAddUrlButtonState extends State<PartyAddUrlButton> {
  final SocketMethods _socketMethods = SocketMethods();
  var playerMe = null;
  bool isBtn = true;
  late PartyStateProvider? party;

  // TextEditingController for the YouTube URL
  TextEditingController urlController = TextEditingController();

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

  // Function to handle the YouTube URL upload
  void handleUrlUpload() async {
    String url = urlController.text.trim();

    if (url.isEmpty) {
      // If the URL is empty, show an error message
      print('Please enter a valid YouTube URL');
      return;
    }

    // Get the current partyId from the provider
    String partyId = party!.partyState['id'];

    // Define the title (e.g., extract from the URL or ask the user to input it)
    String title =
        'New YouTube Track'; // You can ask the user for a title or extract from URL

    // Send the URL to the server to add to the party's tracks collection
    try {
      var response = await http.post(
        Uri.parse('http://192.168.1.213:3000/upload'),
        body: json.encode({
          'url': url,
          'title': title, // Include the title
          'partyId': partyId,
        }),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        print('Track URL added successfully');
        // Optionally, clear the text field after successful addition
        urlController.clear();
      } else {
        print('Failed to add track URL');
      }
    } catch (e) {
      print('Error adding track URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final partyData = Provider.of<PartyStateProvider>(context);

    return playerMe['isPartyLeader'] && isBtn
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Display the button to add a URL
              CustomButton(
                text: 'ADD TRACK',
                onTap: () {
                  // When the button is pressed, show the dialog with a text field
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: Text('Enter YouTube Video URL'),
                        content: TextField(
                          controller: urlController,
                          decoration: InputDecoration(
                            labelText: 'YouTube URL',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              // Close the dialog without adding the track
                              Navigator.of(context).pop();
                            },
                            child: Text('CANCEL'),
                          ),
                          TextButton(
                            onPressed: () {
                              // Handle URL upload when "OK" is pressed
                              handleUrlUpload();
                              Navigator.of(context).pop();
                            },
                            child: Text('OK'),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          )
        : const SizedBox(); // Display nothing if not party leader
  }
}
