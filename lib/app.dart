import 'dart:async';
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

class ActiveDownload {
  final String url;
  final String fileName;
  final String filePath;
  double progress = 0.0;
  int receivedBytes = 0;
  int totalBytes = 0;
  bool isCompleted = false;
  bool hasError = false;
  String? errorMessage;
  StreamSubscription? subscription;
  IOSink? fileSink;
  
  ActiveDownload({
    required this.url,
    required this.fileName,
    required this.filePath,
  });
}

class DownloaderAppState extends State<DownloaderApp> {
  final List<TextEditingController> urlControllers = [TextEditingController()];
  final List<ActiveDownload> activeDownloads = [];
  final List<DownloadItem> downloadHistory = [];
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

    // Start downloads for all URLs
    for (final url in urls) {
      await _startDownload(url);
    }
    
    // Clear URL fields after starting downloads
    for (var controller in urlControllers) {
      controller.clear();
    }
  }
  
  Future<void> _startDownload(String url) async {
    try {
      // Get file name from URL
      final fileName = path.basename(url);

      // Get download directory
      final directory = await _getDownloadDirectory();
      final filePath = path.join(directory.path, fileName);

      // Check if file already exists and create a unique name if needed
      final file = await _createUniqueFile(filePath);
      final uniqueFilePath = file.path;
      final uniqueFileName = path.basename(uniqueFilePath);
      
      // Create active download object
      final activeDownload = ActiveDownload(
        url: url,
        fileName: uniqueFileName,
        filePath: uniqueFilePath,
      );
      
      setState(() {
        activeDownloads.add(activeDownload);
      });

      // Create file and open for writing
      final sink = file.openWrite();
      activeDownload.fileSink = sink;

      // Start downloading
      final request = http.Request('GET', Uri.parse(url));
      final response = await http.Client().send(request);

      final contentLength = response.contentLength ?? -1;
      setState(() {
        activeDownload.totalBytes = contentLength > 0 ? contentLength : -1;
      });

      // Listen to the download stream
      final subscription = response.stream.listen(
        (List<int> chunk) {
          // Update received bytes
          activeDownload.receivedBytes += chunk.length;

          // Write chunk directly to file
          sink.add(chunk);

          // Update progress
          setState(() {
            if (contentLength > 0) {
              activeDownload.progress = activeDownload.receivedBytes / contentLength;
            }
          });
        },
        onDone: () async {
          // Close the file
          await sink.flush();
          await sink.close();
          activeDownload.fileSink = null;

          // Add to history and mark as completed
          setState(() {
            downloadHistory.add(
              DownloadItem(
                url: url,
                fileName: uniqueFileName,
                filePath: uniqueFilePath,
                dateTime: DateTime.now(),
                fileSize: activeDownload.receivedBytes,
              ),
            );
            activeDownload.isCompleted = true;
            activeDownload.progress = 1.0;
          });

          _showSnackBar('Download completed: ${activeDownload.fileName}');
          
          // Remove completed download from active list after a delay
          Future.delayed(const Duration(seconds: 3), () {
            setState(() {
              activeDownloads.remove(activeDownload);
            });
          });
        },
        onError: (error) async {
          // Make sure to close the sink on error
          await sink.close();
          activeDownload.fileSink = null;
          
          setState(() {
            activeDownload.hasError = true;
            activeDownload.errorMessage = error.toString();
          });
          
          _showSnackBar('Error downloading: $error');
        },
        cancelOnError: true,
      );
      
      // Store subscription for possible cancellation
      activeDownload.subscription = subscription;
      
    } catch (e) {
      _showSnackBar('Error starting download for $url: $e');
    }
  }
  
  Future<File> _createUniqueFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return file;
    }
    
    // If file exists, create a unique name by adding a number
    int counter = 1;
    String directory = path.dirname(filePath);
    String fileName = path.basenameWithoutExtension(filePath);
    String extension = path.extension(filePath);
    
    while (true) {
      final newPath = path.join(directory, '$fileName($counter)$extension');
      final newFile = File(newPath);
      if (!await newFile.exists()) {
        return newFile;
      }
      counter++;
    }
  }
  
  void _cancelDownload(ActiveDownload download) async {
    try {
      // Cancel the stream subscription
      await download.subscription?.cancel();
      
      // Close the file sink if it's open
      if (download.fileSink != null) {
        await download.fileSink!.close();
      }
      
      // Delete the partial file
      final file = File(download.filePath);
      if (await file.exists()) {
        await file.delete();
      }
      
      // Remove from active downloads
      setState(() {
        activeDownloads.remove(download);
      });
      
      _showSnackBar('Download cancelled: ${download.fileName}');
    } catch (e) {
      _showSnackBar('Error cancelling download: $e');
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
    // Cancel all active downloads
    for (var download in activeDownloads) {
      download.subscription?.cancel();
      download.fileSink?.close();
    }
    
    // Dispose controllers
    for (var controller in urlControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _buildDownloadItem(ActiveDownload download) {
    final progressText = download.totalBytes > 0
        ? '${_formatBytes(download.receivedBytes, 1)} / ${_formatBytes(download.totalBytes, 1)}'
        : '${_formatBytes(download.receivedBytes, 1)} / Unknown';
        
    final progressPercentage = download.totalBytes > 0
        ? '${(download.progress * 100).toStringAsFixed(1)}%'
        : 'Downloading...';  
        
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    download.fileName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!download.isCompleted && !download.hasError)
                  IconButton(
                    icon: const Icon(Icons.cancel, size: 20),
                    onPressed: () => _cancelDownload(download),
                    tooltip: 'Cancel download',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: download.hasError ? 0 : (download.totalBytes > 0 ? download.progress : null),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              backgroundColor: download.hasError ? Colors.red.withOpacity(0.2) : null,
              color: download.hasError ? Colors.red : (download.isCompleted ? Colors.green : null),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  download.hasError ? 'Error: ${download.errorMessage}' : progressText,
                  style: TextStyle(
                    fontSize: 12,
                    color: download.hasError ? Colors.red : null,
                  ),
                ),
                Text(
                  download.hasError ? 'Failed' : (download.isCompleted ? 'Completed' : progressPercentage),
                  style: TextStyle(
                    fontSize: 12,
                    color: download.hasError ? Colors.red : (download.isCompleted ? Colors.green : null),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
              onPressed: _downloadFile,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
              ),
              child: const Text('Download'),
            ),
            const SizedBox(height: 24.0),
            if (activeDownloads.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('Active Downloads', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  ...activeDownloads.map((download) => _buildDownloadItem(download)).toList(),
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
