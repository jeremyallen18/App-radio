import 'package:flutter/foundation.dart';

@immutable
class BroadcastNotice {
  BroadcastNotice({
    required this.id,
    required this.title,
    required this.preview,
    Map<String, String> data = const {},
  }) : data = Map.unmodifiable(data);

  final String id;
  final String title;
  final String preview;
  final Map<String, String> data;
}
