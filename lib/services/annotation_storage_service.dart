import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

// Import extension methods to access textMarkupRects property
import 'package:syncfusion_flutter_pdfviewer/src/annotation/text_markup.dart'
    show
        HighlightAnnotationExtension,
        UnderlineAnnotationExtension,
        StrikethroughAnnotationExtension,
        SquigglyAnnotationExtension;

/// Service class responsible for storing and retrieving PDF annotations.
class AnnotationStorageService {
  static const String _keyAnnotationPrefix = 'pdf_annotations_';

  /// Saves PDF annotations for a specific file.
  ///
  /// [filePath] is the unique identifier for the PDF file
  /// [annotations] is the list of annotations to save
  static Future<bool> saveAnnotations(
    String filePath,
    List<Annotation> annotations,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getStorageKey(filePath);

      // Convert annotations to serializable format
      final List<Map<String, dynamic>> serializedAnnotations = [];

      for (final annotation in annotations) {
        final data = _serializeAnnotation(annotation);
        if (data != null) {
          serializedAnnotations.add(data);
        }
      }

      // Store as JSON string
      final String annotationsJson = jsonEncode(serializedAnnotations);
      return await prefs.setString(key, annotationsJson);
    } catch (e) {
      debugPrint('Error saving annotations: $e');
      return false;
    }
  }

  /// Loads PDF annotations for a specific file.
  ///
  /// [filePath] is the unique identifier for the PDF file
  /// Returns a list of restored annotations or an empty list if none found
  static Future<List<Annotation>> loadAnnotations(String filePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getStorageKey(filePath);

      if (!prefs.containsKey(key)) {
        return [];
      }

      final String? annotationsJson = prefs.getString(key);
      if (annotationsJson == null || annotationsJson.isEmpty) {
        return [];
      }

      // Decode from JSON
      final List<dynamic> decoded = jsonDecode(annotationsJson);

      // Convert back to Annotation objects
      final List<Annotation> annotations = [];
      for (final item in decoded) {
        final annotation = _deserializeAnnotation(item as Map<String, dynamic>);
        if (annotation != null) {
          annotations.add(annotation);
        }
      }

      return annotations;
    } catch (e) {
      debugPrint('Error loading annotations: $e');
      return [];
    }
  }

  /// Removes all stored annotations for a specific file.
  static Future<bool> clearAnnotations(String filePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getStorageKey(filePath);
      return await prefs.remove(key);
    } catch (e) {
      debugPrint('Error clearing annotations: $e');
      return false;
    }
  }

  /// Returns all files that have saved annotations.
  static Future<List<String>> getFilesWithAnnotations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      return keys
          .where((key) => key.startsWith(_keyAnnotationPrefix))
          .map((key) => key.substring(_keyAnnotationPrefix.length))
          .toList();
    } catch (e) {
      debugPrint('Error getting files with annotations: $e');
      return [];
    }
  }

  /// Generates a unique storage key for a PDF file.
  static String _getStorageKey(String filePath) {
    // Use the hash code to create a unique but consistent key
    return '$_keyAnnotationPrefix${filePath.hashCode}';
  }

  /// Serializes an annotation to a Map for JSON storage.
  static Map<String, dynamic>? _serializeAnnotation(Annotation annotation) {
    try {
      final Map<String, dynamic> data = {
        'type': annotation.runtimeType.toString(),
        'pageNumber': annotation.pageNumber,
        'color': annotation.color.value,
        'opacity': annotation.opacity,
        'isLocked': annotation.isLocked,
      };

      // Add author and subject if present
      if (annotation.author != null) {
        data['author'] = annotation.author;
      }
      if (annotation.subject != null) {
        data['subject'] = annotation.subject;
      }

      // Handle specific annotation types
      if (annotation is StickyNoteAnnotation) {
        data['annotationType'] = 'sticky';
        data['text'] = annotation.text;
        data['icon'] = annotation.icon.index;
        data['position'] = {
          'dx': annotation.position.dx,
          'dy': annotation.position.dy,
        };
      } else if (annotation is HighlightAnnotation) {
        data['annotationType'] = 'highlight';
        // Store textlines as serializable objects
        final textLines = <Map<String, dynamic>>[];
        final List<Rect> markupRects = annotation.textMarkupRects;
        for (int i = 0; i < markupRects.length; i++) {
          final Rect rect = markupRects[i];
          textLines.add({
            'bounds': {
              'left': rect.left,
              'top': rect.top,
              'right': rect.right,
              'bottom': rect.bottom,
            },
            'pageNumber': annotation.pageNumber,
            'text': '', // Text content isn't stored in markup rects
          });
        }
        data['textLines'] = textLines;
      } else if (annotation is UnderlineAnnotation) {
        data['annotationType'] = 'underline';
        final textLines = <Map<String, dynamic>>[];
        final List<Rect> markupRects = annotation.textMarkupRects;
        for (int i = 0; i < markupRects.length; i++) {
          final Rect rect = markupRects[i];
          textLines.add({
            'bounds': {
              'left': rect.left,
              'top': rect.top,
              'right': rect.right,
              'bottom': rect.bottom,
            },
            'pageNumber': annotation.pageNumber,
            'text': '', // Text content isn't stored in markup rects
          });
        }
        data['textLines'] = textLines;
      } else if (annotation is StrikethroughAnnotation) {
        data['annotationType'] = 'strikethrough';
        final textLines = <Map<String, dynamic>>[];
        final List<Rect> markupRects = annotation.textMarkupRects;
        for (int i = 0; i < markupRects.length; i++) {
          final Rect rect = markupRects[i];
          textLines.add({
            'bounds': {
              'left': rect.left,
              'top': rect.top,
              'right': rect.right,
              'bottom': rect.bottom,
            },
            'pageNumber': annotation.pageNumber,
            'text': '', // Text content isn't stored in markup rects
          });
        }
        data['textLines'] = textLines;
      } else if (annotation is SquigglyAnnotation) {
        data['annotationType'] = 'squiggly';
        final textLines = <Map<String, dynamic>>[];
        final List<Rect> markupRects = annotation.textMarkupRects;
        for (int i = 0; i < markupRects.length; i++) {
          final Rect rect = markupRects[i];
          textLines.add({
            'bounds': {
              'left': rect.left,
              'top': rect.top,
              'right': rect.right,
              'bottom': rect.bottom,
            },
            'pageNumber': annotation.pageNumber,
            'text': '', // Text content isn't stored in markup rects
          });
        }
        data['textLines'] = textLines;
      } else {
        // Unknown annotation type
        return null;
      }

      return data;
    } catch (e) {
      debugPrint('Error serializing annotation: $e');
      return null;
    }
  }

  /// Deserializes a Map back to an Annotation object.
  static Annotation? _deserializeAnnotation(Map<String, dynamic> data) {
    try {
      final int pageNumber = data['pageNumber'] as int;
      final Color color = Color(data['color'] as int);
      final double opacity = data['opacity'] as double;
      final bool isLocked = data['isLocked'] as bool? ?? false;
      final String? annotationType = data['annotationType'] as String?;

      // Create the appropriate annotation type
      Annotation? annotation;

      switch (annotationType) {
        case 'sticky':
          final String text = data['text'] as String? ?? '';
          final PdfStickyNoteIcon icon;

          if (data.containsKey('icon') && data['icon'] != null) {
            final int iconIndex = data['icon'] as int;
            if (iconIndex >= 0 && iconIndex < PdfStickyNoteIcon.values.length) {
              icon = PdfStickyNoteIcon.values[iconIndex];
            } else {
              icon = PdfStickyNoteIcon.note;
            }
          } else {
            icon = PdfStickyNoteIcon.note;
          }

          final Map<String, dynamic>? positionData =
              data['position'] as Map<String, dynamic>?;
          final Offset position;

          if (positionData != null) {
            position = Offset(
              (positionData['dx'] as num).toDouble(),
              (positionData['dy'] as num).toDouble(),
            );
          } else {
            position = Offset.zero;
          }

          annotation = StickyNoteAnnotation(
            pageNumber: pageNumber,
            text: text,
            position: position,
            icon: icon,
          );
          break;

        case 'highlight':
        case 'underline':
        case 'strikethrough':
        case 'squiggly':
          final List<dynamic>? textLinesData =
              data['textLines'] as List<dynamic>?;
          if (textLinesData != null) {
            final List<PdfTextLine> textLines = [];

            for (final lineData in textLinesData) {
              final Map<String, dynamic> lineMap =
                  lineData as Map<String, dynamic>;
              final Map<String, dynamic> boundsMap =
                  lineMap['bounds'] as Map<String, dynamic>;
              final Rect bounds = Rect.fromLTRB(
                (boundsMap['left'] as num).toDouble(),
                (boundsMap['top'] as num).toDouble(),
                (boundsMap['right'] as num).toDouble(),
                (boundsMap['bottom'] as num).toDouble(),
              );

              final String text = lineMap['text'] as String? ?? '';
              final int linePage = lineMap['pageNumber'] as int? ?? pageNumber;

              textLines.add(PdfTextLine(bounds, text, linePage));
            }

            if (textLines.isNotEmpty) {
              switch (annotationType) {
                case 'highlight':
                  annotation = HighlightAnnotation(
                    textBoundsCollection: textLines,
                  );
                  break;
                case 'underline':
                  annotation = UnderlineAnnotation(
                    textBoundsCollection: textLines,
                  );
                  break;
                case 'strikethrough':
                  annotation = StrikethroughAnnotation(
                    textBoundsCollection: textLines,
                  );
                  break;
                case 'squiggly':
                  annotation = SquigglyAnnotation(
                    textBoundsCollection: textLines,
                  );
                  break;
              }
            }
          }
          break;
      }

      // Set common properties if annotation was created
      if (annotation != null) {
        annotation.color = color;
        annotation.opacity = opacity;
        annotation.isLocked = isLocked;

        // Set author and subject if present
        if (data.containsKey('author') && data['author'] != null) {
          annotation.author = data['author'] as String?;
        }
        if (data.containsKey('subject') && data['subject'] != null) {
          annotation.subject = data['subject'] as String?;
        }
      }

      return annotation;
    } catch (e) {
      debugPrint('Error deserializing annotation: $e');
      return null;
    }
  }
}
