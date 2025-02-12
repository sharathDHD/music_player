import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Music Player',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<String> _songs = [];
  int _currentSongIndex = 0;
  bool _isPlaying = false;
  double _volume = 0.5; // Default volume
  bool _isShuffle = false; // Default shuffle state
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _initPreferences();
    _audioPlayer.onPlayerComplete.listen((event) {
      if (_isShuffle) {
        _playRandomSong();
      } else {
        _nextSong();
      }
    });
  }

  Future<void> _initPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _volume = _prefs.getDouble('volume') ?? 0.5;
      _isShuffle = _prefs.getBool('shuffle') ?? false;
      _audioPlayer.setVolume(_volume);
    });
  }

  Future<void> _saveVolume(double volume) async {
    setState(() {
      _volume = volume;
      _audioPlayer.setVolume(_volume);
    });
    await _prefs.setDouble('volume', volume);
  }

  Future<void> _saveShuffle(bool shuffle) async {
    setState(() {
      _isShuffle = shuffle;
    });
    await _prefs.setBool('shuffle', shuffle);
  }

  Future<void> _pickSongs() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio, allowMultiple: true);
    if (result != null) {
      setState(() {
        _songs = result.files.map((file) => file.path!).toList();
      });
    }
  }

  void _playSong(String path) async {
    await _audioPlayer.play(DeviceFileSource(path));
    setState(() => _isPlaying = true);
  }

  void _pauseSong() async {
    await _audioPlayer.pause();
    setState(() => _isPlaying = false);
  }

  void _nextSong() {
    if (_songs.isEmpty) return;

    if (_currentSongIndex < _songs.length - 1) {
      _currentSongIndex++;
    } else {
      _currentSongIndex = 0; // Loop back to the beginning
    }
    _playSong(_songs[_currentSongIndex]);
  }

  void _previousSong() {
    if (_songs.isEmpty) return;

    if (_currentSongIndex > 0) {
      _currentSongIndex--;
    } else {
      _currentSongIndex = _songs.length - 1; // Loop to the end
    }
    _playSong(_songs[_currentSongIndex]);
  }

  void _playRandomSong() {
    if (_songs.isEmpty) return;

    final random = DateTime.now().microsecondsSinceEpoch % _songs.length;
    _currentSongIndex = random;
    _playSong(_songs[_currentSongIndex]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Music Player', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: [
              _buildSongsList(),
              _buildMusicPlayer(),
              _buildSettings(),
            ],
          ),
          if (_isPlaying) _buildMiniPlayer(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.library_music), label: 'Songs'),
          BottomNavigationBarItem(icon: Icon(Icons.music_note), label: 'Player'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
        selectedItemColor: Colors.deepPurple,
      ),
    );
  }

  Widget _buildSongsList() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          ElevatedButton(
            onPressed: _pickSongs,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Load Songs'),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _songs.isEmpty
                ? const Center(child: Text('No songs loaded. Please load some music.'))
                : ListView.separated(
              itemCount: _songs.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_songs[index].split('/').last),
                  leading: const Icon(Icons.music_note),
                  onTap: () {
                    _currentSongIndex = index;
                    _playSong(_songs[index]);
                    setState(() => _currentIndex = 1);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMusicPlayer() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Now Playing: ${_songs.isNotEmpty ? _songs[_currentSongIndex].split('/').last : "No Song"}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous, size: 40),
                  onPressed: _previousSong,
                ),
                IconButton(
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, size: 40),
                  onPressed: () => _songs.isNotEmpty ? (_isPlaying ? _pauseSong() : _playSong(_songs[_currentSongIndex])) : null,
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next, size: 40),
                  onPressed: _nextSong,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniPlayer() {
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = 1), // Open full player on tap
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          padding: const EdgeInsets.all(10),
          color: Colors.grey[300],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _songs.isNotEmpty ? _songs[_currentSongIndex].split('/').last : "No Song",
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.skip_previous),
                    onPressed: _previousSong,
                  ),
                  IconButton(
                    icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                    onPressed: () => _songs.isNotEmpty ? (_isPlaying ? _pauseSong() : _playSong(_songs[_currentSongIndex])) : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next),
                    onPressed: _nextSong,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettings() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Text('Settings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Volume'),
              Slider(
                value: _volume,
                min: 0,
                max: 1,
                onChanged: (value) => _saveVolume(value),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Shuffle'),
              Switch(
                value: _isShuffle,
                onChanged: (value) => _saveShuffle(value),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
