import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Una franja horaria de un programa: un día + su propia hora de inicio/fin.
/// Reemplaza al viejo horario único (mismo rango para todos los días
/// seleccionados) para poder representar p.ej. "miércoles 9-13, viernes
/// 11-13" del mismo programa — ver `site_programa_slots()` en hive-backend.
class SiteScheduleSlot {
  SiteScheduleSlot({this.weekday = 1, this.startHour, this.endHour});

  int weekday;
  int? startHour;
  int? endHour;

  factory SiteScheduleSlot.fromJson(Map<String, dynamic> json) =>
      SiteScheduleSlot(
        weekday: int.tryParse(json['weekday']?.toString() ?? '') ?? 1,
        startHour: int.tryParse(json['start_hour']?.toString() ?? ''),
        endHour: int.tryParse(json['end_hour']?.toString() ?? ''),
      );

  Map<String, dynamic> toJson() =>
      {'weekday': weekday, 'start_hour': startHour, 'end_hour': endHour};
}

@immutable
class ProgramModel extends Equatable {
  const ProgramModel({
    this.id,
    required this.title,
    required this.modalTitle,
    required this.host,
    required this.hostTeamIds,
    required this.slots,
    required this.badgeIcon,
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
  final List<SiteScheduleSlot> slots;
  final String badgeIcon;
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
        slots: const [],
        badgeIcon: defaultBadgeIcon,
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
    final rawSlots = item['slots'];
    return ProgramModel(
      id: int.tryParse(item['id']?.toString() ?? ''),
      title: item['title']?.toString() ?? '',
      modalTitle: item['modal_title']?.toString() ?? '',
      host: item['host']?.toString() ?? '',
      hostTeamIds: _parseIntSet(item['host_team_ids']),
      slots: rawSlots is List
          ? rawSlots
              .map((s) => SiteScheduleSlot.fromJson(
                  Map<String, dynamic>.from(s as Map)))
              .toList()
          : const [],
      badgeIcon: _orDefault(
        item['badge_icon']?.toString(),
        defaultBadgeIcon,
      ),
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
    List<SiteScheduleSlot>? slots,
    String? badgeIcon,
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
      slots: slots ?? this.slots,
      badgeIcon: badgeIcon ?? this.badgeIcon,
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
        'slots_json': jsonEncode(slots.map((s) => s.toJson()).toList()),
        'badge_icon': badgeIcon,
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
        slots,
        badgeIcon,
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
