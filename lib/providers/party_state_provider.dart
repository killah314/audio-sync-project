import 'package:audio_sync_prototype/models/party_state.dart';
import 'package:flutter/material.dart';

class PartyStateProvider extends ChangeNotifier {
  PartyState _partyState = PartyState(
    id: '',
    players: [],
    isJoin: true,
    isOver: false,
    tracks: [],
  );

  int _currentTrackIndex = 0;
  bool _isPlaying = false;
  Duration _currentTrackPosition = Duration.zero;

  Map<String, dynamic> get partyState => _partyState.toJson();

  int get currentTrackIndex => _currentTrackIndex;
  bool get isPlaying => _isPlaying;
  Duration get currentTrackPosition =>
      _currentTrackPosition; // Getter for current track position

  // Setter for isPlaying
  set isPlaying(bool value) {
    _isPlaying = value;
    notifyListeners(); // Notify listeners to update the UI when the play/pause state changes
  }

  void updatePartyState({
    required id,
    required players,
    required isJoin,
    required isOver,
    required tracks,
  }) {
    _partyState = PartyState(
      id: id,
      players: players,
      isJoin: isJoin,
      isOver: isOver,
      tracks: tracks,
    );
    notifyListeners();
  }

  // Remove track from the local list
  void removeTrack(String trackId) {
    // Ensure tracks is a list and remove track by trackId
    _partyState.tracks.removeWhere((track) => track['_id'] == trackId);
    notifyListeners(); // Notify listeners to update the UI
  }

  // Add a method to remove player from the party state
  void removePlayer(String socketID) {
    partyState['players'] = partyState['players']
        .where((player) => player['socketID'] != socketID)
        .toList();
    notifyListeners();
  }

  // Add a method to update the party's join status
  void updatePartyJoinStatus(bool status) {
    partyState['isJoin'] = status;
    notifyListeners();
  }

  // Playback Control Methods

  // Play a specific track
  void playTrack(int index) {
    _currentTrackIndex = index;
    _isPlaying = true;
    notifyListeners();
  }

  void setPlaying(bool isPlaying) {
    this.isPlaying = isPlaying;
    notifyListeners(); // Notify listeners to update the UI
  }

  // Pause playback
  void pauseTrack(index) {
    _currentTrackIndex = index;
    _isPlaying = false;
    notifyListeners();
  }

  // Play next track (circular)
  void nextTrack() {
    if (_partyState.tracks.isNotEmpty) {
      _currentTrackIndex = (_currentTrackIndex + 1) % _partyState.tracks.length;
      _isPlaying = true;
      notifyListeners();
    }
  }

  // Play previous track (circular)
  void previousTrack() {
    if (_partyState.tracks.isNotEmpty) {
      _currentTrackIndex =
          (_currentTrackIndex - 1 + _partyState.tracks.length) %
              _partyState.tracks.length;
      _isPlaying = true;
      notifyListeners();
    }
  }

  // Get the current track details
  Map<String, dynamic> get currentTrack {
    if (_partyState.tracks.isNotEmpty) {
      return _partyState.tracks[_currentTrackIndex];
    }
    return {};
  }

  // Method to update the track position
  void updateTrackPosition(Duration newPosition) {
    _currentTrackPosition = newPosition;
    notifyListeners(); // Notify listeners about the position change
  }
}
