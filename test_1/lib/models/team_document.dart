import 'package:flutter/material.dart';
import 'package:doliv_social/design/design.dart';

/// Un archivo del apartado "Documentos" de un equipo (GET /document/list).
class TeamDocument {
  final String id;
  final String docName;
  final String originalName;
  final String? mime;
  final int fileSize;
  final String uploadedBy;
  final DateTime createdAt;

  TeamDocument({
    required this.id,
    required this.docName,
    required this.originalName,
    required this.mime,
    required this.fileSize,
    required this.uploadedBy,
    required this.createdAt,
  });

  factory TeamDocument.fromJson(Map<String, dynamic> json) {
    return TeamDocument(
      id: json['id'].toString(),
      docName: (json['docName'] ?? json['originalName'] ?? 'Documento').toString(),
      originalName:
          (json['originalName'] ?? json['docName'] ?? 'documento').toString(),
      mime: json['mime']?.toString(),
      fileSize: json['fileSize'] is int
          ? json['fileSize'] as int
          : int.tryParse('${json['fileSize']}') ?? 0,
      uploadedBy: (json['uploadedBy'] ?? '').toString(),
      createdAt:
          DateTime.tryParse('${json['createdAt']}')?.toLocal() ?? DateTime.now(),
    );
  }

  String get extension {
    final i = originalName.lastIndexOf('.');
    return i >= 0 ? originalName.substring(i + 1).toLowerCase() : '';
  }

  String get formattedSize {
    if (fileSize <= 0) return '';
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Ícono + color según el tipo de archivo, para distinguir de un vistazo
  /// PDFs, hojas de cálculo, presentaciones, etc.
  ({IconData icon, Color color}) get typeStyle {
    switch (extension) {
      case 'pdf':
        return (icon: Icons.picture_as_pdf_rounded, color: AppColors.error);
      case 'doc':
      case 'docx':
        return (icon: Icons.description_rounded, color: AppColors.accent);
      case 'xls':
      case 'xlsx':
      case 'csv':
        return (icon: Icons.table_chart_rounded, color: AppColors.success);
      case 'ppt':
      case 'pptx':
        return (icon: Icons.slideshow_rounded, color: AppColors.warning);
      case 'zip':
      case 'rar':
      case '7z':
        return (icon: Icons.folder_zip_rounded, color: AppColors.accentStrong);
      case 'txt':
        return (icon: Icons.article_rounded, color: AppColors.textMuted);
      default:
        return (icon: Icons.insert_drive_file_rounded, color: AppColors.textMuted);
    }
  }
}
