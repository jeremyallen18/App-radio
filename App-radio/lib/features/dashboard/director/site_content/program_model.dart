import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

@immutable
class ProgramModel extends Equatable {
  const ProgramModel({
    this.id,
    required this.title,
    required this.modalTitle,
    required this.host,
    required this.hostTeamIds,
    required this.schedule,
    required this.slotStart,
    required this.slotEnd,
    required this.weekdays,
    required this.badgeIcon,
    required this.badgeTime,
    required this.badgeLabel,
    required this.accent,
    required this.icon,
    required this.categories,
    required this.cardDesc,
    required this.indexDesc,
    required this.summary,
    required this.orderIndex,
  });

  final int? id;
  final String title;
  final String modalTitle;
  final String host;
  final Set<int> hostTeamIds;
  final String schedule;
  final int? slotStart;
  final int? slotEnd;
  final Set<int> weekdays;
  final String badgeIcon;
  final String badgeTime;
  final String badgeLabel;
  final String accent;
  final String icon;
  final List<String> categories;
  final String cardDesc;
  final String indexDesc;
  final String summary;
  final int orderIndex;

  static const defaultAccent = '#2563EB';
  static const defaultIcon = 'radio';
  static const defaultBadgeIcon = 'radio';
  static const defaultTag = 'Música';

  factory ProgramModel.empty({int orderIndex = 0}) => ProgramModel(
        title: '',
        modalTitle: '',
        host: '',
        hostTeamIds: const {},
        schedule: '',
        slotStart: null,
        slotEnd: null,
        weekdays: const {},
        badgeIcon: defaultBadgeIcon,
        badgeTime: '',
        badgeLabel: 'Al aire',
        accent: defaultAccent,
        icon: defaultIcon,
        categories: const [defaultTag],
        cardDesc: '',
        indexDesc: '',
        summary: '',
        orderIndex: orderIndex,
      );

  factory ProgramModel.fromSiteItem(Map<String, dynamic> item) {
    return ProgramModel(
      id: int.tryParse(item['id']?.toString() ?? ''),
      title: item['title']?.toString() ?? '',
      modalTitle: item['modal_title']?.toString() ?? '',
      host: item['host']?.toString() ?? '',
      hostTeamIds: _parseIntSet(item['host_team_ids']),
      schedule: item['schedule']?.toString() ?? '',
      slotStart: int.tryParse(item['slot_start']?.toString() ?? ''),
      slotEnd: int.tryParse(item['slot_end']?.toString() ?? ''),
      weekdays: _parseIntCsv(item['weekdays']?.toString() ?? ''),
      badgeIcon: _orDefault(
        item['badge_icon']?.toString(),
        defaultBadgeIcon,
      ),
      badgeTime: item['badge_time']?.toString() ?? '',
      badgeLabel: _orDefault(item['badge_label']?.toString(), 'Al aire'),
      accent: _orDefault(item['accent']?.toString(), defaultAccent),
      icon: _orDefault(item['icon']?.toString(), defaultIcon),
      categories: _parseTags(item['categories']?.toString() ?? ''),
      cardDesc: item['card_desc']?.toString() ?? '',
      indexDesc: item['index_desc']?.toString() ?? '',
      summary: item['summary']?.toString() ?? '',
      orderIndex: int.tryParse(item['sort_order']?.toString() ?? '') ?? 0,
    );
  }

  bool get isValid => title.trim().isNotEmpty;

  ProgramModel copyWith({
    int? id,
    String? title,
    String? modalTitle,
    String? host,
    Set<int>? hostTeamIds,
    String? schedule,
    int? slotStart,
    int? slotEnd,
    Set<int>? weekdays,
    String? badgeIcon,
    String? badgeTime,
    String? badgeLabel,
    String? accent,
    String? icon,
    List<String>? categories,
    String? cardDesc,
    String? indexDesc,
    String? summary,
    int? orderIndex,
  }) {
    return ProgramModel(
      id: id ?? this.id,
      title: title ?? this.title,
      modalTitle: modalTitle ?? this.modalTitle,
      host: host ?? this.host,
      hostTeamIds: hostTeamIds ?? this.hostTeamIds,
      schedule: schedule ?? this.schedule,
      slotStart: slotStart ?? this.slotStart,
      slotEnd: slotEnd ?? this.slotEnd,
      weekdays: weekdays ?? this.weekdays,
      badgeIcon: badgeIcon ?? this.badgeIcon,
      badgeTime: badgeTime ?? this.badgeTime,
      badgeLabel: badgeLabel ?? this.badgeLabel,
      accent: accent ?? this.accent,
      icon: icon ?? this.icon,
      categories: categories ?? this.categories,
      cardDesc: cardDesc ?? this.cardDesc,
      indexDesc: indexDesc ?? this.indexDesc,
      summary: summary ?? this.summary,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }

  Map<String, String> toSiteFields() => {
        'title': title.trim(),
        'modal_title': modalTitle.trim(),
        'host': host.trim(),
        'host_team_ids': hostTeamIds.join(','),
        'schedule': schedule.trim(),
        'slot_start': slotStart?.toString() ?? '',
        'slot_end': slotEnd?.toString() ?? '',
        'weekdays': (weekdays.toList()..sort()).join(','),
        'badge_icon': badgeIcon,
        'badge_time': badgeTime.trim(),
        'badge_label': badgeLabel.trim(),
        'accent': accent,
        'icon': icon,
        'categories': categories.join(', '),
        'card_desc': cardDesc.trim(),
        'index_desc': indexDesc.trim(),
        'summary': summary.trim(),
        'sort_order': orderIndex.toString(),
      };

  @override
  List<Object?> get props => [
        id,
        title,
        modalTitle,
        host,
        hostTeamIds,
        schedule,
        slotStart,
        slotEnd,
        weekdays,
        badgeIcon,
        badgeTime,
        badgeLabel,
        accent,
        icon,
        categories,
        cardDesc,
        indexDesc,
        summary,
        orderIndex,
      ];

  static int nextOrderIndex(Iterable<Map<String, dynamic>> existingPrograms) {
    final maxOrder = existingPrograms
        .map((program) => int.tryParse(program['sort_order']?.toString() ?? ''))
        .whereType<int>()
        .fold<int>(0, (currentMax, value) {
      return value > currentMax ? value : currentMax;
    });
    return maxOrder + 1;
  }

  static Set<int> _parseIntSet(dynamic value) {
    if (value is! List) return const {};
    return value
        .map((v) => int.tryParse(v.toString()))
        .whereType<int>()
        .toSet();
  }

  static Set<int> _parseIntCsv(String value) {
    return value
        .split(',')
        .map((part) => int.tryParse(part.trim()))
        .whereType<int>()
        .where((day) => day >= 1 && day <= 7)
        .toSet();
  }

  static List<String> _parseTags(String value) {
    final tags = value
        .split(RegExp(r'[,\n]'))
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
    return tags.isEmpty ? const [defaultTag] : List.unmodifiable(tags);
  }

  static String _orDefault(String? value, String fallback) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? fallback : trimmed;
  }
}
