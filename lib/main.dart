import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = true;

  void toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Async Downloader',
      debugShowCheckedModeBanner: false,
      theme:
          _isDarkMode
              ? ThemeData.dark().copyWith(
                primaryColor: const Color(0xFF00272B),
                scaffoldBackgroundColor: const Color(0xFF00272B),
                colorScheme: ColorScheme.dark(
                  primary: const Color(0xFFE0FF4F),
                  secondary: const Color(0xFFE0FF4F),
                  surface: const Color(0xFF003640),
                ),
                appBarTheme: const AppBarTheme(
                  backgroundColor: Color(0xFF00272B),
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                filledButtonTheme: FilledButtonThemeData(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE0FF4F),
                    foregroundColor: const Color(0xFF00272B),
                  ),
                ),
              )
              : ThemeData.light().copyWith(
                primaryColor: Colors.white,
                colorScheme: ColorScheme.light(
                  primary: const Color(0xFF00272B),
                  secondary: const Color(0xFF00272B),
                  surface: Colors.grey[100]!,
                ),
                appBarTheme: const AppBarTheme(
                  backgroundColor: Colors.white,
                  foregroundColor: Color(0xFF00272B),
                  elevation: 0,
                ),
                filledButtonTheme: FilledButtonThemeData(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00272B),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
      home: DownloaderApp(toggleTheme: toggleTheme, isDarkMode: _isDarkMode),
    );
  }
}

class DownloaderApp extends StatefulWidget {
  final Function toggleTheme;
  final bool isDarkMode;

  const DownloaderApp({
    super.key,
    required this.toggleTheme,
    required this.isDarkMode,
  });

  @override
  State<DownloaderApp> createState() => _DownloaderAppState();
}

class _DownloaderAppState extends State<DownloaderApp> {
  final TextEditingController _urlController = TextEditingController();
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  final List<DownloadItem> _downloadHistory = [];
  int _selectedSegment = 0;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await Permission.storage.request();
    }
  }

  Future<void> _downloadFile() async {
    if (_urlController.text.isEmpty) {
      _showSnackBar('Please enter a URL');
      return;
    }

    final url = _urlController.text.trim();

    try {
      setState(() {
        _isDownloading = true;
        _downloadProgress = 0.0;
      });

      // Get file name from URL
      final fileName = path.basename(url);

      // Get download directory
      final directory = await _getDownloadDirectory();
      final filePath = path.join(directory.path, fileName);

      // Create file
      final file = File(filePath);

      // Start downloading
      final request = http.Request('GET', Uri.parse(url));
      final response = await http.Client().send(request);

      final contentLength = response.contentLength ?? 0;
      int receivedBytes = 0;

      List<int> bytes = [];

      response.stream.listen(
        (List<int> chunk) {
          // Update received bytes
          receivedBytes += chunk.length;
          bytes.addAll(chunk);

          // Update progress
          if (contentLength > 0) {
            setState(() {
              _downloadProgress = receivedBytes / contentLength;
            });
          }
        },
        onDone: () async {
          // Write to file
          await file.writeAsBytes(bytes);

          // Add to history
          setState(() {
            _downloadHistory.add(
              DownloadItem(
                url: url,
                fileName: fileName,
                filePath: filePath,
                dateTime: DateTime.now(),
              ),
            );
            _isDownloading = false;
            _downloadProgress = 1.0;
          });

          _showSnackBar('Download completed: $fileName');

          // Reset progress after a moment
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _downloadProgress = 0.0;
              });
            }
          });
        },
        onError: (error) {
          setState(() {
            _isDownloading = false;
          });
          _showSnackBar('Error downloading: $error');
        },
        cancelOnError: true,
      );
    } catch (e) {
      setState(() {
        _isDownloading = false;
      });
      _showSnackBar('Error: $e');
    }
  }

  Future<Directory> _getDownloadDirectory() async {
    if (Platform.isAndroid) {
      // For Android, we'll use the downloads directory
      return Directory('/storage/emulated/0/Download');
    } else {
      // For iOS and others, we'll use the documents directory
      return await getApplicationDocumentsDirectory();
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color textColor =
        widget.isDarkMode ? Colors.white : const Color(0xFF00272B);
    final Color accentColor =
        widget.isDarkMode ? const Color(0xFFE0FF4F) : const Color(0xFF00272B);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('Async Downloader', style: TextStyle(color: textColor)),
        actions: [
          IconButton(
            icon: Icon(
              widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: textColor,
            ),
            onPressed: () => widget.toggleTheme(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: CupertinoSegmentedControl<int>(
              selectedColor: accentColor,
              borderColor: accentColor,
              groupValue: _selectedSegment,
              children: {
                0: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.download,
                        color:
                            _selectedSegment == 0
                                ? (widget.isDarkMode
                                    ? Colors.black
                                    : Colors.white)
                                : textColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Download',
                        style: TextStyle(
                          color:
                              _selectedSegment == 0
                                  ? (widget.isDarkMode
                                      ? Colors.black
                                      : Colors.white)
                                  : textColor,
                        ),
                      ),
                    ],
                  ),
                ),
                1: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history,
                        color:
                            _selectedSegment == 1
                                ? (widget.isDarkMode
                                    ? Colors.black
                                    : Colors.white)
                                : textColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'History',
                        style: TextStyle(
                          color:
                              _selectedSegment == 1
                                  ? (widget.isDarkMode
                                      ? Colors.black
                                      : Colors.white)
                                  : textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              },
              onValueChanged: (int value) {
                setState(() {
                  _selectedSegment = value;
                });
              },
            ),
          ),
          Expanded(
            child:
                _selectedSegment == 0
                    ? _buildDownloaderTab()
                    : _buildHistoryTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloaderTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              hintText: 'Paste download URL here',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => _urlController.clear(),
              ),
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
          ),
          const SizedBox(height: 16.0),
          FilledButton(
            onPressed: _isDownloading ? null : _downloadFile,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
            ),
            child: Text(_isDownloading ? 'Downloading...' : 'Download'),
          ),
          const SizedBox(height: 24.0),
          if (_isDownloading || _downloadProgress > 0)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Download Progress: ${(_downloadProgress * 100).toStringAsFixed(1)}%',
                ),
                const SizedBox(height: 8.0),
                LinearProgressIndicator(
                  value: _downloadProgress,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(5),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_downloadHistory.isEmpty) {
      return const Center(child: Text('No download history yet'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _downloadHistory.length,
      itemBuilder: (context, index) {
        final item = _downloadHistory[_downloadHistory.length - 1 - index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          child: ListTile(
            leading: const Icon(Icons.file_download_done),
            title: Text(item.fileName),
            subtitle: Text(
              '${item.url}\n${item.dateTime.toString().substring(0, 16)}',
            ),
            isThreeLine: true,
            trailing: IconButton(
              icon: const Icon(Icons.open_in_new),
              onPressed: () {
                _showSnackBar('Opening file: ${item.fileName}');
                // Here you could add functionality to open the file
              },
            ),
          ),
        );
      },
    );
  }
}

class DownloadItem {
  final String url;
  final String fileName;
  final String filePath;
  final DateTime dateTime;

  DownloadItem({
    required this.url,
    required this.fileName,
    required this.filePath,
    required this.dateTime,
  });
}
