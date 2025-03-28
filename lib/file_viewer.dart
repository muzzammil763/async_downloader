import 'dart:io';
import 'dart:math' as math;

import 'package:async_downloader/download_item.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';

class FileViewerScreen extends StatelessWidget {
  final DownloadItem downloadItem;
  final bool isDarkMode;

  const FileViewerScreen({
    super.key,
    required this.downloadItem,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final Color textColor = isDarkMode ? Colors.white : const Color(0xFF00272B);
    final Color accentColor =
        isDarkMode ? const Color(0xFFE0FF4F) : const Color(0xFF00272B);

    final File file = File(downloadItem.filePath);
    final bool fileExists = file.existsSync();
    final String fileExtension =
        path.extension(downloadItem.fileName).toLowerCase();

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('File Viewer', style: TextStyle(color: textColor)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (fileExists)
            IconButton(
              icon: Icon(Icons.share, color: textColor),
              onPressed: () => _shareFile(context),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFileInfoCard(context, textColor, accentColor),
          Expanded(
            child:
                fileExists
                    ? _buildFilePreview(context, fileExtension)
                    : _buildFileNotFound(context),
          ),
        ],
      ),
      bottomNavigationBar:
          fileExists ? _buildBottomActions(context, accentColor) : null,
    );
  }

  Widget _buildFileInfoCard(
    BuildContext context,
    Color textColor,
    Color accentColor,
  ) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      elevation: 2.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_getFileIcon(), color: accentColor, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        downloadItem.fileName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatBytes(downloadItem.fileSize, 2),
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Downloaded on: ${_formatDateTime(downloadItem.dateTime)}',
              style: TextStyle(
                color: textColor.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Location: ${downloadItem.filePath}',
              style: TextStyle(
                color: textColor.withValues(alpha: 0.7),
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilePreview(BuildContext context, String fileExtension) {
    switch (fileExtension) {
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.gif':
        return _buildImagePreview();
      case '.txt':
      case '.json':
      case '.csv':
      case '.md':
        return _buildTextPreview();
      case '.pdf':
        return _buildPdfPreview();
      default:
        return _buildGenericPreview();
    }
  }

  Widget _buildImagePreview() {
    return Center(
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 3.0,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Image.file(
            File(downloadItem.filePath),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return _buildPreviewError('Failed to load image');
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTextPreview() {
    try {
      final String content = File(downloadItem.filePath).readAsStringSync();
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Text(content, style: const TextStyle(fontSize: 14)),
      );
    } catch (e) {
      return _buildPreviewError('Failed to read text file: $e');
    }
  }

  Widget _buildPdfPreview() {
    // This would require a PDF viewer package like flutter_pdfview
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.picture_as_pdf,
            size: 80,
            color: isDarkMode ? Colors.white70 : Colors.black54,
          ),
          const SizedBox(height: 16),
          const Text('PDF Preview', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open with PDF Viewer'),
            onPressed: () => _openFile(),
          ),
        ],
      ),
    );
  }

  Widget _buildGenericPreview() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getFileIcon(),
            size: 100,
            color: isDarkMode ? Colors.white70 : Colors.black54,
          ),
          const SizedBox(height: 24),
          Text(
            'File type: ${path.extension(downloadItem.fileName).toUpperCase().replaceAll('.', '')}',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'Preview not available',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open with External App'),
            onPressed: () => _openFile(),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewError(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: const Text('Try External App'),
            onPressed: () => _openFile(),
          ),
        ],
      ),
    );
  }

  Widget _buildFileNotFound(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 80,
            color: Colors.amber,
          ),
          const SizedBox(height: 16),
          const Text(
            'File Not Found',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'The file may have been moved or deleted.',
            style: TextStyle(
              fontSize: 16,
              color: isDarkMode ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(CupertinoIcons.arrow_left),
            label: const Text('Go Back'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context, Color accentColor) {
    return BottomAppBar(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionButton(
              context,
              Icons.open_in_new,
              'Open',
              () => _openFile(),
              accentColor,
            ),
            _buildActionButton(
              context,
              Icons.delete_outline,
              'Delete',
              () => _confirmDelete(context),
              accentColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onPressed,
    Color accentColor,
  ) {
    return Expanded(
      child: TextButton.icon(
        icon: Icon(icon, color: accentColor),
        label: Text(label, style: TextStyle(color: accentColor)),
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
        ),
      ),
    );
  }

  void _openFile() {
    OpenFile.open(downloadItem.filePath).then((result) {
      if (result.type != ResultType.done) {
        // ScaffoldMessenger.of(
        //   this.context,
        // ).showSnackBar(SnackBar(content: Text('Error: ${result.message}')));
      }
    });
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete File?'),
            content: Text(
              'Are you sure you want to delete "${downloadItem.fileName}"?',
            ),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.pop(context),
              ),
              TextButton(
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  _deleteFile(context);
                },
              ),
            ],
          ),
    );
  }

  void _deleteFile(BuildContext context) {
    try {
      final file = File(downloadItem.filePath);
      if (file.existsSync()) {
        file.deleteSync();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File deleted successfully')),
        );
        Navigator.pop(context); // Go back to previous screen
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('File not found')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting file: $e')));
    }
  }

  IconData _getFileIcon() {
    final String extension =
        path.extension(downloadItem.fileName).toLowerCase();

    switch (extension) {
      case '.pdf':
        return Icons.picture_as_pdf;
      case '.doc':
      case '.docx':
        return Icons.description;
      case '.xls':
      case '.xlsx':
        return Icons.table_chart;
      case '.ppt':
      case '.pptx':
        return Icons.slideshow;
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.gif':
        return Icons.image;
      case '.mp3':
      case '.wav':
      case '.aac':
        return Icons.audio_file;
      case '.mp4':
      case '.mov':
      case '.avi':
        return Icons.video_file;
      case '.zip':
      case '.rar':
      case '.7z':
        return Icons.folder_zip;
      case '.txt':
      case '.md':
        return Icons.article;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatBytes(int bytes, int decimals) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB", "PB"];
    var i = (math.log(bytes) / math.log(1024)).floor();
    return '${(bytes / math.pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
  
  void _shareFile(BuildContext context) async {
    try {
      final file = File(downloadItem.filePath);
      if (await file.exists()) {
        // Get file mime type based on extension
        final mimeType = _getMimeType(path.extension(downloadItem.fileName).toLowerCase());
        
        // Show sharing dialog
        await Share.shareXFiles(
          [XFile(downloadItem.filePath, mimeType: mimeType)],
          subject: 'Sharing ${downloadItem.fileName}',
          text: 'Sharing file downloaded from ${downloadItem.url}',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File not found')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing file: $e')),
      );
    }
  }
  
  String _getMimeType(String fileExtension) {
    switch (fileExtension) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.pdf':
        return 'application/pdf';
      case '.txt':
        return 'text/plain';
      case '.doc':
      case '.docx':
        return 'application/msword';
      case '.xls':
      case '.xlsx':
        return 'application/vnd.ms-excel';
      case '.ppt':
      case '.pptx':
        return 'application/vnd.ms-powerpoint';
      case '.mp3':
        return 'audio/mpeg';
      case '.mp4':
        return 'video/mp4';
      case '.zip':
        return 'application/zip';
      case '.json':
        return 'application/json';
      case '.csv':
        return 'text/csv';
      default:
        return 'application/octet-stream'; // Default binary data
    }
  }
}
