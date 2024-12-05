import 'package:flutter/material.dart';

class PartyScreen extends StatefulWidget {
  @override
  _PartyScreenState createState() => _PartyScreenState();
}

class _PartyScreenState extends State<PartyScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Party Time!'),
      ),
      body: Center(
        child: Text('Playlist and sync controls will be here'),
      ),
    );
  }
}
