import 'package:flutter/material.dart';
import 'package:audio_sync_prototype/widgets/custom_button.dart';
//import 'create_room_screen.dart';
//import 'join_room_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Audio Sync',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 50,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 2,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: CustomButton(
                text: 'Create a Room',
                onTap: () => Navigator.pushNamed(context, '/create-room'),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: CustomButton(
                text: 'Join a Room',
                onTap: () => Navigator.pushNamed(context, '/join-room'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
