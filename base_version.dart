import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';

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
    if (_currentSongIndex < _songs.length - 1) {
      _currentSongIndex++;
      _playSong(_songs[_currentSongIndex]);
    }
  }

  void _previousSong() {
    if (_currentSongIndex > 0) {
      _currentSongIndex--;
      _playSong(_songs[_currentSongIndex]);
    }
  }

  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _pages.addAll([
      _buildSongsList(),
      _buildMusicPlayer(),
      _buildSettings(),
    ]);
  }

  Widget _buildSongsList() {
    return Column(
      children: [
        ElevatedButton(
          onPressed: _pickSongs,
          child: const Text('Load Songs'),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _songs.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text('Song ${index + 1}'),
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
    );
  }

  Widget _buildMusicPlayer() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Now Playing: Song ${_currentSongIndex + 1}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.skip_previous, size: 40),
              onPressed: _previousSong,
            ),
            IconButton(
              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, size: 40),
              onPressed: () => _isPlaying ? _pauseSong() : _playSong(_songs[_currentSongIndex]),
            ),
            IconButton(
              icon: const Icon(Icons.skip_next, size: 40),
              onPressed: _nextSong,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSettings() {
    return const Center(
      child: Text('Settings Page - Coming Soon!', style: TextStyle(fontSize: 20)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flutter Music Player')),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.library_music), label: 'Songs'),
          BottomNavigationBarItem(icon: Icon(Icons.music_note), label: 'Player'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
