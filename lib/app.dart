import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:async_downloader/download_item.dart';
import 'package:async_downloader/file_viewer.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class DownloaderApp extends StatefulWidget {
  final Function toggleTheme;
  final bool isDarkMode;

  const DownloaderApp({
    super.key,
    required this.toggleTheme,
    required this.isDarkMode,
  });

  @override
  State<DownloaderApp> createState() => DownloaderAppState();
}

class DownloaderAppState extends State<DownloaderApp> {
  final List<TextEditingController> urlControllers = [TextEditingController()];
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  final List<DownloadItem> downloadHistory = [];
  int _selectedSegment = 0;
  int _receivedBytes = 0;
  int _totalBytes = 0;

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

  String _formatBytes(int bytes, int decimals) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB", "PB"];
    var i = (math.log(bytes) / math.log(1024)).floor();
    return '${(bytes / math.pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  Future<void> _downloadFile() async {
    final urls =
        urlControllers
            .map((c) => c.text.trim())
            .where((url) => url.isNotEmpty)
            .toList();

    if (urls.isEmpty) {
      _showSnackBar('Please Enter At Least One URL');
      return;
    }

    for (final url in urls) {
      try {
        setState(() {
          _isDownloading = true;
          _downloadProgress = 0.0;
          _receivedBytes = 0;
          _totalBytes = 0;
        });

        /// Get file name from URL
        final fileName = path.basename(url);

        /// Get download directory
        final directory = await _getDownloadDirectory();
        final filePath = path.join(directory.path, fileName);

        /// Create file and open for writing
        final file = File(filePath);
        final sink = file.openWrite();

        /// Start downloading
        final request = http.Request('GET', Uri.parse(url));
        final response = await http.Client().send(request);

        final contentLength = response.contentLength ?? -1;
        setState(() {
          _totalBytes = contentLength > 0 ? contentLength : -1;
        });

        int receivedBytes = 0;

        response.stream.listen(
          (List<int> chunk) {
            /// Update received bytes
            receivedBytes += chunk.length;

            /// Write chunk directly to file
            sink.add(chunk);

            /// Update progress
            setState(() {
              _receivedBytes = receivedBytes;
              if (contentLength > 0) {
                _downloadProgress = receivedBytes / contentLength;
              }
            });
          },
          onDone: () async {
            /// Close the file
            await sink.flush();
            await sink.close();

            /// Add to history
            setState(() {
              downloadHistory.add(
                DownloadItem(
                  url: url,
                  fileName: fileName,
                  filePath: filePath,
                  dateTime: DateTime.now(),
                  fileSize: receivedBytes,
                ),
              );
              _isDownloading = false;
              _downloadProgress = 1.0;
            });

            /// Reset progress after a moment
            setState(() {
              _downloadProgress = 0.0;
            });
            _showSnackBar('Download completed: $fileName');
          },
          onError: (error) async {
            /// Make sure to close the sink on error
            await sink.close();
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
        _showSnackBar('Error downloading $url: $e');
      }
    }
  }

  Future<Directory> _getDownloadDirectory() async {
    if (Platform.isAndroid) {
      /// For Android, we'll use the downloads directory
      return Directory('/storage/emulated/0/Download');
    } else {
      /// For iOS and others, we'll use the documents directory
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
    for (var controller in urlControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _buildResponsiveWrapper(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const mobileMaxWidth = 600.0; // Standard mobile width breakpoint

        if (constraints.maxWidth <= mobileMaxWidth) {
          return child;
        }

        // For larger screens, center the app with mobile width
        return Stack(
          children: [
            // Blurred background using button color
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Theme.of(context).colorScheme.surface,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                child: Container(),
              ),
            ),
            // Centered app content
            Center(
              child: Container(
                padding: const EdgeInsets.all(8.0),
                width: mobileMaxWidth,
                constraints: BoxConstraints(
                  maxHeight: math.min(constraints.maxHeight, 800.0),
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color textColor =
        widget.isDarkMode ? Colors.white : const Color(0xFF00272B);
    final Color accentColor =
        widget.isDarkMode ? const Color(0xFFE0FF4F) : const Color(0xFF00272B);

    return _buildResponsiveWrapper(
      Scaffold(
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
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoSegmentedControl<int>(
                  selectedColor: accentColor,
                  borderColor: accentColor,
                  groupValue: _selectedSegment,
                  children: {
                    0: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.cloud_download,
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
                            CupertinoIcons.clock,
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
            ),
            Expanded(
              child:
                  _selectedSegment == 0
                      ? _buildDownloaderTab()
                      : _buildHistoryTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloaderTab() {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            urlControllers.add(TextEditingController());
          });
        },
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: urlControllers.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: urlControllers[index],
                            decoration: InputDecoration(
                              hintText: 'Paste download URL here',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              suffixIcon: IconButton(
                                icon: const Icon(CupertinoIcons.clear),
                                onPressed: () => urlControllers[index].clear(),
                              ),
                            ),
                            keyboardType: TextInputType.url,
                            autocorrect: false,
                          ),
                        ),
                        if (index > 0)
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () {
                              setState(() {
                                urlControllers[index].dispose();
                                urlControllers.removeAt(index);
                              });
                            },
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16.0),
            FilledButton(
              onPressed: _isDownloading ? null : _downloadFile,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
              ),
              child: Text(_isDownloading ? 'Downloading ...' : 'Download'),
            ),
            const SizedBox(height: 24.0),
            if (_isDownloading || _downloadProgress > 0)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _totalBytes > 0
                            ? 'Progress: ${(_downloadProgress * 100).toStringAsFixed(1)}%'
                            : 'Downloading...',
                      ),
                      Text(
                        _totalBytes > 0
                            ? '${_formatBytes(_receivedBytes, 1)} of ${_formatBytes(_totalBytes, 1)}'
                            : 'Downloaded: ${_formatBytes(_receivedBytes, 1)}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8.0),
                  LinearProgressIndicator(
                    value: _totalBytes > 0 ? _downloadProgress : null,
                    // Indeterminate if size unknown
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(5),
                    backgroundColor: Colors.grey[300],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (downloadHistory.isEmpty) {
      return const Center(child: Text('No Download History Yet'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: downloadHistory.length,
      itemBuilder: (context, index) {
        final item = downloadHistory[downloadHistory.length - 1 - index];
        return Card.outlined(
          color: Colors.transparent,
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          child: ListTile(
            leading: const Icon(CupertinoIcons.check_mark_circled),
            title: Text(item.fileName),
            subtitle: Text(
              '${item.url}\n${item.dateTime.toString().substring(0, 16)}',
            ),
            isThreeLine: true,
            trailing: IconButton(
              icon: const Icon(CupertinoIcons.arrow_up_right_square),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => FileViewerScreen(
                          downloadItem: item,
                          isDarkMode: widget.isDarkMode,
                        ),
                  ),
                );
              },
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => FileViewerScreen(
                        downloadItem: item,
                        isDarkMode: widget.isDarkMode,
                      ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
