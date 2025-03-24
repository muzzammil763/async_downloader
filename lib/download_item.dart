class DownloadItem {
  final String url;
  final String fileName;
  final String filePath;
  final DateTime dateTime;
  final int fileSize;

  DownloadItem({
    required this.url,
    required this.fileName,
    required this.filePath,
    required this.dateTime,
    required this.fileSize,
  });
}
