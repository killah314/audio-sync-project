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
  Duration get currentTrackPosition => _currentTrackPosition;

  set isPlaying(bool value) {
    _isPlaying = value;
    notifyListeners();
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

  void removeTrack(String trackId) {
    _partyState.tracks.removeWhere((track) => track['_id'] == trackId);
    notifyListeners();
  }

  void removePlayer(String socketID) {
    partyState['players'] = partyState['players']
        .where((player) => player['socketID'] != socketID)
        .toList();
    notifyListeners();
  }

  void updatePartyJoinStatus(bool status) {
    partyState['isJoin'] = status;
    notifyListeners();
  }

  void playTrack(int index) {
    _currentTrackIndex = index;
    _isPlaying = true;
    notifyListeners();
  }

  void setPlaying(bool isPlaying) {
    this.isPlaying = isPlaying;
    notifyListeners();
  }

  void pauseTrack(index) {
    _currentTrackIndex = index;
    _isPlaying = false;
    notifyListeners();
  }

  void nextTrack() {
    if (_partyState.tracks.isNotEmpty) {
      _currentTrackIndex = (_currentTrackIndex + 1) % _partyState.tracks.length;
      _isPlaying = true;
      notifyListeners();
    }
  }

  void previousTrack() {
    if (_partyState.tracks.isNotEmpty) {
      _currentTrackIndex =
          (_currentTrackIndex - 1 + _partyState.tracks.length) %
              _partyState.tracks.length;
      _isPlaying = true;
      notifyListeners();
    }
  }

  Map<String, dynamic> get currentTrack {
    if (_partyState.tracks.isNotEmpty) {
      return _partyState.tracks[_currentTrackIndex];
    }
    return {};
  }

  void updateTrackPosition(Duration newPosition) {
    _currentTrackPosition = newPosition;
    notifyListeners();
  }

  void updateTrackState(int trackIndex, bool isPlaying) {
    _currentTrackIndex = trackIndex;
    _isPlaying = isPlaying;
    notifyListeners();
  }

  void syncTrackState(int trackIndex, bool isPlaying, Duration position) {
    _currentTrackIndex = trackIndex;
    _isPlaying = isPlaying;
    _currentTrackPosition = position;
    notifyListeners();
  }

  void updatePlayerInfo(String socketID, Map<String, dynamic> updatedInfo) {
    int playerIndex = _partyState.players
        .indexWhere((player) => player['socketID'] == socketID);
    if (playerIndex != -1) {
      _partyState.players[playerIndex] = updatedInfo;
      notifyListeners();
    }
  }

  void updatePlayersList(List<dynamic> updatedPlayers) {
    partyState['players'] = updatedPlayers;
    notifyListeners();
  }
}
