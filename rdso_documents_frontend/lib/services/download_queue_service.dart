import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../utils/pdf_helper.dart';
import 'api_service.dart';

enum DownloadStatus { pending, downloading, completed, failed }

class DownloadTask {
  final String documentId;
  final String name;
  final String? fetchUrl;
  DownloadStatus status;
  String? savedPath;

  DownloadTask({
    required this.documentId,
    required this.name,
    this.fetchUrl,
    this.status = DownloadStatus.pending,
    this.savedPath,
  });

  Map<String, dynamic> toJson() => {
        'documentId': documentId,
        'name': name,
        'fetchUrl': fetchUrl,
        'status': status.name,
        'savedPath': savedPath,
      };

  factory DownloadTask.fromJson(Map<String, dynamic> json) => DownloadTask(
        documentId: json['documentId'],
        name: json['name'],
        fetchUrl: json['fetchUrl'],
        status: DownloadStatus.values.byName(json['status'] ?? 'pending'),
        savedPath: json['savedPath'],
      );
}

class DownloadQueueService extends ChangeNotifier {
  static const _storageKey = 'download_queue';
  final List<DownloadTask> _queue = [];
  bool _isProcessing = false;

  List<DownloadTask> get queue => List.unmodifiable(_queue);
  bool get isProcessing => _isProcessing;
  int get pendingCount =>
      _queue.where((t) => t.status == DownloadStatus.pending).length;
  int get activeCount =>
      _queue.where((t) => t.status == DownloadStatus.downloading).length;

  Future<void> init() async {
    await _loadQueue();
    // Auto-process any pending tasks
    unawaited(processQueue());
  }

  Future<void> _loadQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        _queue.clear();
        for (final item in list) {
          final task = DownloadTask.fromJson(item);
          // Reset any in-flight downloads from a previous session
          if (task.status == DownloadStatus.downloading) {
            task.status = DownloadStatus.pending;
          }
          // Only restore pending/failed, skip completed
          if (task.status != DownloadStatus.completed) {
            _queue.add(task);
          }
        }
        notifyListeners();
      } catch (_) {
        // Corrupted data — start fresh
      }
    }
  }

  Future<void> _saveQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final pending =
        _queue.where((t) => t.status != DownloadStatus.completed).toList();
    await prefs.setString(
        _storageKey, jsonEncode(pending.map((t) => t.toJson()).toList()));
  }

  /// Add one or more documents to the download queue.
  Future<void> enqueue(List<DownloadTask> tasks) async {
    for (final task in tasks) {
      // Avoid duplicates
      if (!_queue.any((t) =>
          t.documentId == task.documentId &&
          t.status != DownloadStatus.completed &&
          t.status != DownloadStatus.failed)) {
        _queue.add(task);
      }
    }
    await _saveQueue();
    notifyListeners();
    unawaited(processQueue());
  }

  /// Process all pending downloads sequentially.
  Future<void> processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;
    notifyListeners();

    while (_queue.any((t) => t.status == DownloadStatus.pending)) {
      final task =
          _queue.firstWhere((t) => t.status == DownloadStatus.pending);
      task.status = DownloadStatus.downloading;
      notifyListeners();

      try {
        final headers = await ApiService().authHeaders();
        final url = task.fetchUrl ??
          '${ApiConfig.baseUrl}/documents/?document_ids=${task.documentId}&download=true';
        final bytes = await fetchPdfBytes(url, headers);

        if (bytes != null && bytes.isNotEmpty) {
          final path = await savePdfFile(bytes, '${task.documentId}.pdf');
          task.status = DownloadStatus.completed;
          task.savedPath = path;
        } else {
          task.status = DownloadStatus.failed;
        }
      } catch (_) {
        task.status = DownloadStatus.failed;
      }

      await _saveQueue();
      notifyListeners();
    }

    _isProcessing = false;
    notifyListeners();
  }

  /// Retry all failed downloads.
  Future<void> retryFailed() async {
    for (final task in _queue) {
      if (task.status == DownloadStatus.failed) {
        task.status = DownloadStatus.pending;
      }
    }
    await _saveQueue();
    notifyListeners();
    unawaited(processQueue());
  }

  /// Remove completed tasks from the list.
  void clearCompleted() {
    _queue.removeWhere((t) => t.status == DownloadStatus.completed);
    notifyListeners();
  }
}
