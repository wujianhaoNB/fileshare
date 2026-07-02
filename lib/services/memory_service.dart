import 'dart:math';
import '../core/logger/app_logger.dart';
import '../data/repositories/chat_repository.dart';

/// A single memory fact extracted by the AI.
class MemoryEntry {
  final String id;
  final String key;
  final String value;
  final String category;
  final double confidence;
  final String? sourceConversationId;
  final DateTime createdAt;
  DateTime lastAccessedAt;
  int accessCount;

  MemoryEntry({
    required this.id, required this.key, required this.value, required this.category,
    this.confidence = 0.5, this.sourceConversationId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       lastAccessedAt = createdAt ?? DateTime.now(),
       accessCount = 0;

  Map<String, dynamic> toJson() => {
    'id': id, 'key': key, 'value': value, 'category': category,
    'confidence': confidence, 'created_at': createdAt.toIso8601String(),
    'access_count': accessCount,
  };

  /// Compute a simple embedding vector for this memory (keyword-based for MVP).
  /// Will upgrade to real embeddings in Phase 2.
  List<double> toKeywordVector(Map<String, int> vocabulary, int dimSize) {
    final vector = List<double>.filled(dimSize, 0.0);
    final text = '$key $value'.toLowerCase();
    final words = text.split(RegExp(r'\s+'));
    for (final word in words) {
      final idx = vocabulary[word];
      if (idx != null && idx < dimSize) vector[idx] = 1.0;
    }
    return vector;
  }

  double cosineSimilarity(List<double> a, List<double> b) {
    var dot = 0.0, normA = 0.0, normB = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0 || normB == 0) return 0;
    return dot / (sqrt(normA) * sqrt(normB));
  }
}

/// Three-tier memory system for the AI assistant.
/// Phase 0: In-memory keyword-vector storage
/// Phase 2: SQLite + embedding-based semantic search
class MemoryService {
  final AppLogger _logger = AppLogger();
  final List<MemoryEntry> _memories = [];
  Map<String, int> _vocabulary = {};
  static const int _vectorDim = 128;

  List<MemoryEntry> get allMemories => List.unmodifiable(_memories);

  /// Store a new memory.
  void remember(MemoryEntry entry) {
    _memories.removeWhere((m) => m.key == entry.key);
    _memories.add(entry);
    _updateVocabulary(entry);
    _logger.debug('Memory stored: ${entry.key} (${entry.category})');
  }

  /// Recall memories relevant to a query using keyword-vector cosine similarity.
  List<MemoryEntry> recall(String query, {int topK = 5, String? category, double minConfidence = 0.3}) {
    if (_memories.isEmpty) return [];

    // Build query vector
    final queryVector = _textToVector(query);
    List<MemoryEntry> candidates = _memories.where((m) => m.confidence >= minConfidence).toList();
    if (category != null) candidates = candidates.where((m) => m.category == category).toList();
    if (candidates.isEmpty) return [];

    // Score by cosine similarity
    final scored = candidates.map((m) {
      final memVector = m.toKeywordVector(_vocabulary, _vectorDim);
      return (m, queryVector != null ? m.cosineSimilarity(queryVector, memVector) : 0.0);
    }).toList();

    scored.sort((a, b) => b.$2.compareTo(a.$2));
    final result = scored.take(topK).map((s) {
      s.$1.lastAccessedAt = DateTime.now();
      s.$1.accessCount++;
      return s.$1;
    }).toList();

    return result;
  }

  /// Forget a memory.
  void forget(String key) {
    _memories.removeWhere((m) => m.key == key);
  }

  /// Get memory summary for system prompt injection.
  String getContextInjection(String query, {int maxMemories = 5}) {
    final relevant = recall(query, topK: maxMemories);
    if (relevant.isEmpty) return '';
    return '\n\n## 相关记忆\n${relevant.map((m) => '- ${m.key}: ${m.value} (${m.category})').join('\n')}\n';
  }

  /// Count memories by category.
  Map<String, int> get categoryCounts {
    final counts = <String, int>{};
    for (final m in _memories) counts[m.category] = (counts[m.category] ?? 0) + 1;
    return counts;
  }

  void _updateVocabulary(MemoryEntry entry) {
    final text = '${entry.key} ${entry.value}'.toLowerCase();
    for (final word in text.split(RegExp(r'\s+'))) {
      if (!_vocabulary.containsKey(word) && _vocabulary.length < _vectorDim) {
        _vocabulary[word] = _vocabulary.length;
      }
    }
  }

  List<double>? _textToVector(String text) {
    final words = text.toLowerCase().split(RegExp(r'\s+'));
    final vector = List<double>.filled(_vectorDim, 0.0);
    var hasWord = false;
    for (final word in words) {
      final idx = _vocabulary[word];
      if (idx != null && idx < _vectorDim) {
        vector[idx] = 1.0;
        hasWord = true;
      }
    }
    return hasWord ? vector : null;
  }

  void clear() {
    _memories.clear();
    _vocabulary.clear();
  }
}
