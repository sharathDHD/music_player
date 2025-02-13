import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(MyApp());
}

/// Ensure your pubspec.yaml includes:
///   audioplayers: ^6.1.2
///   permission_handler: ^11.3.1
///   file_picker: ^5.2.2
///   path_provider: ^2.0.15
///
/// Also configure your native splash screen and app icon to use
/// assets/song_logo.png (which should have a transparent background).

enum RepeatModeCustom { none, one, all }

/// Returns a simple gradient based on brightness.
LinearGradient getGradient(Brightness brightness) {
  if (brightness == Brightness.dark) {
    return LinearGradient(
      colors: [Colors.black, Colors.grey.shade900],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  } else {
    return LinearGradient(
      colors: [Colors.white, Colors.grey.shade300],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

/// The app supports light and dark modes.
class _MyAppState extends State<MyApp> {
  bool isDarkMode = false;
  void toggleTheme(bool value) {
    setState(() {
      isDarkMode = value;
    });
  }
  @override
  Widget build(BuildContext context) {
    final lightTheme = ThemeData.light().copyWith(
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: AppBarTheme(backgroundColor: Colors.white, foregroundColor: Colors.black),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
      ),
    );
    final darkTheme = ThemeData.dark().copyWith(
      scaffoldBackgroundColor: Colors.black,
      appBarTheme: AppBarTheme(backgroundColor: Colors.black, foregroundColor: Colors.white),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
      ),
    );
    return MaterialApp(
      title: 'SK Music Player',
      theme: isDarkMode ? darkTheme : lightTheme,
      home: HomePage(
        toggleTheme: toggleTheme,
        isDarkMode: isDarkMode,
      ),
    );
  }
}

/// HomePage holds the BottomNavigationBar, AudioPlayer instance,
/// and manages the playlist, playback modes, favorites, and queue.
class HomePage extends StatefulWidget {
  final Function(bool) toggleTheme;
  final bool isDarkMode;
  HomePage({required this.toggleTheme, required this.isDarkMode});
  @override
  _HomePageState createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentSongPath;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool isPlaying = false;

  // Playlist and favorites management.
  List<String> _playlist = [];
  int _currentIndex = -1;
  bool _shuffleEnabled = false;
  RepeatModeCustom _repeatMode = RepeatModeCustom.none;
  final Random _random = Random();
  Set<String> _favorites = {};

  @override
  void initState() {
    super.initState();
    _audioPlayer.onDurationChanged.listen((Duration d) {
      setState(() { _duration = d; });
    });
    _audioPlayer.onPositionChanged.listen((Duration p) {
      setState(() { _position = p; });
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      if (_repeatMode == RepeatModeCustom.one) {
        _playSong(_playlist[_currentIndex], _currentIndex);
      } else if (_repeatMode == RepeatModeCustom.all) {
        _playNext();
      } else {
        setState(() { isPlaying = false; });
      }
    });
  }

  /// Plays the song at [path] and updates the current index.
  void _playSong(String path, [int? index]) async {
    if (index != null) {
      _currentIndex = index;
    } else {
      _currentIndex = _playlist.indexOf(path);
    }
    _currentSongPath = path;
    await _audioPlayer.play(DeviceFileSource(path));
    setState(() { isPlaying = true; });
  }

  void _pauseSong() async {
    await _audioPlayer.pause();
    setState(() { isPlaying = false; });
  }

  void _resumeSong() async {
    await _audioPlayer.resume();
    setState(() { isPlaying = true; });
  }

  void _seekSong(Duration position) {
    _audioPlayer.seek(position);
  }

  void _playNext() {
    if (_playlist.isEmpty) return;
    if (_shuffleEnabled) {
      int nextIndex = _random.nextInt(_playlist.length);
      _playSong(_playlist[nextIndex], nextIndex);
    } else {
      int nextIndex = _currentIndex + 1;
      if (nextIndex >= _playlist.length) nextIndex = 0;
      _playSong(_playlist[nextIndex], nextIndex);
    }
  }

  void _playPrevious() {
    if (_playlist.isEmpty) return;
    if (_shuffleEnabled) {
      int prevIndex = _random.nextInt(_playlist.length);
      _playSong(_playlist[prevIndex], prevIndex);
    } else {
      int prevIndex = _currentIndex - 1;
      if (prevIndex < 0) prevIndex = _playlist.length - 1;
      _playSong(_playlist[prevIndex], prevIndex);
    }
  }

  void _toggleShuffle() {
    setState(() {
      _shuffleEnabled = !_shuffleEnabled;
    });
  }

  void _toggleRepeatMode() {
    setState(() {
      if (_repeatMode == RepeatModeCustom.none) {
        _repeatMode = RepeatModeCustom.one;
      } else if (_repeatMode == RepeatModeCustom.one) {
        _repeatMode = RepeatModeCustom.all;
      } else {
        _repeatMode = RepeatModeCustom.none;
      }
    });
  }

  void _updatePlaylist(List<String> playlist) {
    setState(() {
      _playlist = playlist;
      if (playlist.isNotEmpty && _currentIndex == -1) {
        _playSong(playlist[0], 0);
      }
    });
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _toggleFavorite(String path) {
    setState(() {
      if (_favorites.contains(path)) {
        _favorites.remove(path);
      } else {
        _favorites.add(path);
      }
    });
  }

  void _showQueue() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          color: widget.isDarkMode ? Colors.grey[900] : Colors.grey[200],
          child: ListView.separated(
            padding: EdgeInsets.all(16),
            itemCount: _playlist.length,
            separatorBuilder: (context, index) => Divider(),
            itemBuilder: (context, index) {
              String songPath = _playlist[index];
              String songName = songPath.split('/').last;
              return ListTile(
                title: Text(songName, style: TextStyle(fontSize: 16)),
                onTap: () {
                  Navigator.pop(context);
                  _playSong(songPath, index);
                },
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = widget.isDarkMode ? Brightness.dark : Brightness.light;
    final backgroundColor = widget.isDarkMode ? Colors.black : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black;
    return Scaffold(
      appBar: AppBar(
        title: Text('SK Music Player', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: backgroundColor,
        elevation: 0,
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          SongsPage(
            onSongSelected: (path) => _playSong(path, _playlist.indexOf(path)),
            onPlaylistLoaded: _updatePlaylist,
            currentSongPath: _currentSongPath,
            currentSongDuration: _currentSongPath == null ? Duration.zero : _duration,
            formatDuration: _formatDuration,
            backgroundColor: backgroundColor,
            favorites: _favorites,
            onToggleFavorite: _toggleFavorite,
          ),
          FavoritesPage(
            favorites: _favorites.toList(),
            onSongSelected: (path) => _playSong(path, _playlist.indexOf(path)),
            formatDuration: _formatDuration,
            backgroundColor: backgroundColor,
          ),
          PlayerPage(
            audioPlayer: _audioPlayer,
            currentSongPath: _currentSongPath,
            isPlaying: isPlaying,
            onPause: _pauseSong,
            onResume: _resumeSong,
            position: _position,
            duration: _duration,
            onSeek: _seekSong,
            onNext: _playNext,
            onPrevious: _playPrevious,
            onShuffle: _toggleShuffle,
            onRepeat: _toggleRepeatMode,
            shuffleEnabled: _shuffleEnabled,
            repeatMode: _repeatMode,
            formatDuration: _formatDuration,
            backgroundColor: backgroundColor,
            onShowQueue: _showQueue,
          ),
          SettingsPage(
            isDarkMode: widget.isDarkMode,
            onThemeChanged: widget.toggleTheme,
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(top: 8),
        color: backgroundColor,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_selectedIndex != 2 && _currentSongPath != null)
              MiniPlayer(
                currentSongPath: _currentSongPath!,
                isPlaying: isPlaying,
                onPause: _pauseSong,
                onResume: _resumeSong,
                onNext: _playNext,
                onPrevious: _playPrevious,
                onShuffle: _toggleShuffle,
                onRepeat: _toggleRepeatMode,
                repeatMode: _repeatMode,
                shuffleEnabled: _shuffleEnabled,
                backgroundColor: backgroundColor,
              ),
            BottomNavigationBar(
              backgroundColor: backgroundColor,
              currentIndex: _selectedIndex,
              iconSize: 28,
              selectedFontSize: 16,
              unselectedFontSize: 14,
              onTap: (i) {
                setState(() {
                  _selectedIndex = i;
                });
              },
              items: [
                BottomNavigationBarItem(
                    icon: Icon(Icons.library_music, color: textColor), label: 'Songs'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.favorite, color: textColor), label: 'Favorites'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.play_arrow, color: textColor), label: 'Player'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.settings, color: textColor), label: 'Settings'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// SongsPage displays a list of songs with improved spacing, styling, and favorite functionality.
class SongsPage extends StatefulWidget {
  final Function(String) onSongSelected;
  final Function(List<String>) onPlaylistLoaded;
  final String? currentSongPath;
  final Duration currentSongDuration;
  final String Function(Duration) formatDuration;
  final Color backgroundColor;
  final Set<String> favorites;
  final Function(String) onToggleFavorite;
  SongsPage({
    required this.onSongSelected,
    required this.onPlaylistLoaded,
    this.currentSongPath,
    required this.currentSongDuration,
    required this.formatDuration,
    required this.backgroundColor,
    required this.favorites,
    required this.onToggleFavorite,
  });
  @override
  _SongsPageState createState() => _SongsPageState();
}
class _SongsPageState extends State<SongsPage> {
  List<FileSystemEntity> audioFiles = [];
  bool loading = true;
  @override
  void initState() {
    super.initState();
    _fetchSongs();
  }
  Future<void> _fetchSongs() async {
    Map<Permission, PermissionStatus> statuses =
    await [Permission.storage, Permission.audio].request();
    bool granted = statuses[Permission.storage]?.isGranted == true ||
        statuses[Permission.audio]?.isGranted == true;
    if (!granted) {
      setState(() { loading = false; });
      return;
    }
    Directory? extDir = await getExternalStorageDirectory();
    List<String> dirs;
    if (extDir != null) {
      String basePath = extDir.parent.parent.parent.parent.path;
      dirs = [
        '$basePath/Music',
        '$basePath/Download',
        '$basePath/Songs',
        '$basePath/Audio',
      ];
    } else {
      dirs = [
        '/storage/emulated/0/Music',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Songs',
        '/storage/emulated/0/Audio',
      ];
    }
    List<FileSystemEntity> files = [];
    for (String dirPath in dirs) {
      Directory dir = Directory(dirPath);
      if (await dir.exists()) {
        try {
          var entities = dir.listSync(recursive: true);
          files.addAll(entities.where((entity) {
            String path = entity.path.toLowerCase();
            return path.endsWith('.mp3') ||
                path.endsWith('.wav') ||
                path.endsWith('.m4a') ||
                path.endsWith('.aac');
          }));
        } catch (e) {
          print("Error scanning directory $dirPath: $e");
        }
      }
    }
    setState(() {
      audioFiles = files;
      loading = false;
    });
    widget.onPlaylistLoaded(audioFiles.map((e) => e.path).toList());
  }
  Future<void> _selectFolder() async {
    String? folderPath = await FilePicker.platform.getDirectoryPath();
    if (folderPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Folder selection cancelled or restricted.')));
      return;
    }
    try {
      List<FileSystemEntity> files = Directory(folderPath)
          .listSync(recursive: true)
          .where((entity) {
        String path = entity.path.toLowerCase();
        return path.endsWith('.mp3') ||
            path.endsWith('.wav') ||
            path.endsWith('.m4a') ||
            path.endsWith('.aac');
      }).toList();
      setState(() {
        audioFiles = files;
      });
      widget.onPlaylistLoaded(files.map((e) => e.path).toList());
      if (files.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No audio files found in this folder.')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scanning folder: $e')));
    }
  }
  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black;
    return Container(
      color: widget.backgroundColor,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: loading
          ? Center(child: CircularProgressIndicator())
          : audioFiles.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('No audio files found.', style: TextStyle(color: textColor, fontSize: 18)),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _selectFolder,
              child: Text('Select Folder'),
            ),
          ],
        ),
      )
          : ListView.separated(
        itemCount: audioFiles.length,
        separatorBuilder: (context, index) => Divider(color: textColor.withOpacity(0.6)),
        itemBuilder: (context, index) {
          String filePath = audioFiles[index].path;
          String fileName = filePath.split('/').last;
          String durationText = (widget.currentSongPath == filePath)
              ? widget.currentSongDuration.inSeconds > 0
              ? widget.formatDuration(widget.currentSongDuration)
              : "00:00"
              : "00:00";
          bool isFavorite = widget.favorites.contains(filePath);
          return ListTile(
            contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            leading: Icon(Icons.music_note_outlined, color: textColor, size: 28),
            title: Text(fileName,
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16, color: textColor)),
            subtitle: Text(durationText, style: TextStyle(color: textColor.withOpacity(0.7))),
            trailing: IconButton(
              icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.red : textColor),
              onPressed: () {
                widget.onToggleFavorite(filePath);
              },
            ),
            onTap: () { widget.onSongSelected(filePath); },
          );
        },
      ),
    );
  }
}

/// FavoritesPage displays the list of favorite songs.
class FavoritesPage extends StatelessWidget {
  final List<String> favorites;
  final Function(String) onSongSelected;
  final String Function(Duration) formatDuration;
  final Color backgroundColor;
  FavoritesPage({
    required this.favorites,
    required this.onSongSelected,
    required this.formatDuration,
    required this.backgroundColor,
  });
  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black;
    return Container(
      color: backgroundColor,
      padding: EdgeInsets.all(16),
      child: favorites.isEmpty
          ? Center(child: Text('No favorite songs yet.', style: TextStyle(fontSize: 18, color: textColor)))
          : ListView.separated(
        itemCount: favorites.length,
        separatorBuilder: (context, index) => Divider(color: textColor.withOpacity(0.6)),
        itemBuilder: (context, index) {
          String filePath = favorites[index];
          String fileName = filePath.split('/').last;
          return ListTile(
            contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            leading: Icon(Icons.music_note, color: textColor, size: 28),
            title: Text(fileName,
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16, color: textColor)),
            onTap: () => onSongSelected(filePath),
          );
        },
      ),
    );
  }
}

/// PlayerPage displays a full‑screen player with improved UI, including a queue feature.
class PlayerPage extends StatefulWidget {
  final AudioPlayer audioPlayer;
  final String? currentSongPath;
  final bool isPlaying;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final Duration position;
  final Duration duration;
  final Function(Duration) onSeek;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onShuffle;
  final VoidCallback onRepeat;
  final bool shuffleEnabled;
  final RepeatModeCustom repeatMode;
  final String Function(Duration) formatDuration;
  final Color backgroundColor;
  final VoidCallback onShowQueue;
  PlayerPage({
    required this.audioPlayer,
    required this.currentSongPath,
    required this.isPlaying,
    required this.onPause,
    required this.onResume,
    required this.position,
    required this.duration,
    required this.onSeek,
    required this.onNext,
    required this.onPrevious,
    required this.onShuffle,
    required this.onRepeat,
    required this.shuffleEnabled,
    required this.repeatMode,
    required this.formatDuration,
    required this.backgroundColor,
    required this.onShowQueue,
  });
  @override
  _PlayerPageState createState() => _PlayerPageState();
}
class _PlayerPageState extends State<PlayerPage> {
  double volume = 1.0;
  void _changeVolume(double value) {
    setState(() {
      volume = value;
    });
    widget.audioPlayer.setVolume(volume);
  }
  @override
  Widget build(BuildContext context) {
    if (widget.currentSongPath == null)
      return Center(child: Text('No song selected.', style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, fontSize: 18)));
    String songName = widget.currentSongPath!.split('/').last;
    final screenHeight = MediaQuery.of(context).size.height;
    final textColor = Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black;
    return Container(
      height: screenHeight,
      decoration: BoxDecoration(color: widget.backgroundColor),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Song image takes 40% of screen height.
          Container(
            height: screenHeight * 0.40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: AssetImage('assets/song_logo.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          SizedBox(height: 12),
          Text(songName,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textColor)),
          SizedBox(height: 8),
          // Current time and total duration.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.formatDuration(widget.position), style: TextStyle(color: textColor)),
              Text(widget.formatDuration(widget.duration), style: TextStyle(color: textColor)),
            ],
          ),
          SizedBox(height: 4),
          Slider(
            activeColor: textColor,
            inactiveColor: textColor.withOpacity(0.5),
            value: widget.position.inSeconds.toDouble(),
            max: widget.duration.inSeconds > 0 ? widget.duration.inSeconds.toDouble() : 1,
            onChanged: (value) {
              widget.onSeek(Duration(seconds: value.toInt()));
            },
          ),
          SizedBox(height: 12),
          // Control buttons with added Queue button.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(icon: Icon(Icons.queue_music, size: 32, color: textColor), onPressed: widget.onShowQueue),
              IconButton(icon: Icon(Icons.skip_previous, size: 36, color: textColor), onPressed: widget.onPrevious),
              IconButton(
                icon: Icon(widget.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, size: 64, color: textColor),
                onPressed: () {
                  widget.isPlaying ? widget.onPause() : widget.onResume();
                },
              ),
              IconButton(icon: Icon(Icons.skip_next, size: 36, color: textColor), onPressed: widget.onNext),
              IconButton(icon: Icon(Icons.shuffle, size: 36, color: widget.shuffleEnabled ? textColor.withOpacity(0.8) : textColor), onPressed: widget.onShuffle),
              IconButton(
                icon: widget.repeatMode == RepeatModeCustom.none
                    ? Icon(Icons.repeat, size: 36, color: textColor.withOpacity(0.5))
                    : widget.repeatMode == RepeatModeCustom.one
                    ? Icon(Icons.repeat_one, size: 36, color: textColor)
                    : Icon(Icons.repeat, size: 36, color: textColor),
                onPressed: widget.onRepeat,
              ),
            ],
          ),
          SizedBox(height: 12),
          // Volume slider.
          Row(
            children: [
              Icon(Icons.volume_down, color: textColor),
              Expanded(
                child: Slider(
                  activeColor: textColor,
                  inactiveColor: textColor.withOpacity(0.5),
                  value: volume,
                  min: 0,
                  max: 1,
                  onChanged: _changeVolume,
                ),
              ),
              Icon(Icons.volume_up, color: textColor),
            ],
          ),
        ],
      ),
    );
  }
}

/// MiniPlayer displays a compact control bar with icon-only controls, placed just above the BottomNavigationBar.
class MiniPlayer extends StatelessWidget {
  final String currentSongPath;
  final bool isPlaying;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onShuffle;
  final VoidCallback onRepeat;
  final RepeatModeCustom repeatMode;
  final bool shuffleEnabled;
  final Color backgroundColor;
  MiniPlayer({
    required this.currentSongPath,
    required this.isPlaying,
    required this.onPause,
    required this.onResume,
    required this.onNext,
    required this.onPrevious,
    required this.onShuffle,
    required this.onRepeat,
    required this.repeatMode,
    required this.shuffleEnabled,
    required this.backgroundColor,
  });
  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black;
    String songName = currentSongPath.split('/').last;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8),
      height: 48,
      color: backgroundColor,
      child: Row(
        children: [
          IconButton(icon: Icon(Icons.skip_previous, color: textColor, size: 24), onPressed: onPrevious),
          IconButton(icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: textColor, size: 24), onPressed: () => isPlaying ? onPause() : onResume()),
          IconButton(icon: Icon(Icons.skip_next, color: textColor, size: 24), onPressed: onNext),
          IconButton(icon: Icon(Icons.shuffle, color: shuffleEnabled ? textColor.withOpacity(0.7) : textColor, size: 24), onPressed: onShuffle),
          IconButton(
            icon: repeatMode == RepeatModeCustom.none
                ? Icon(Icons.repeat, color: textColor.withOpacity(0.5), size: 24)
                : repeatMode == RepeatModeCustom.one
                ? Icon(Icons.repeat_one, color: textColor, size: 24)
                : Icon(Icons.repeat, color: textColor, size: 24),
            onPressed: onRepeat,
          ),
          SizedBox(width: 4),
          Icon(Icons.music_note_outlined, color: textColor, size: 24),
          SizedBox(width: 4),
          Expanded(
            child: Text(
              songName,
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// SettingsPage provides a switch to toggle light/dark mode.
class SettingsPage extends StatelessWidget {
  final bool isDarkMode;
  final Function(bool) onThemeChanged;
  SettingsPage({required this.isDarkMode, required this.onThemeChanged});
  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black;
    return Center(
      child: SwitchListTile(
        title: Text('Dark Mode', style: TextStyle(color: textColor, fontSize: 18)),
        value: isDarkMode,
        onChanged: onThemeChanged,
      ),
    );
  }
}

/// Returns a simple black-and-white gradient for the PlayerPage.
LinearGradient getBWGradient() {
  return LinearGradient(
    colors: [Colors.black, Colors.grey.shade900],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
