import 'package:epubx/epubx.dart';
import 'package:epub_view/src/data/epub_cfi/_generator.dart';
import 'package:epub_view/src/data/epub_cfi/_parser.dart';

/// A utility class for generating and interpreting EPUB CFI (Canon Fragment Identifier) strings.
/// CFI is a standardized way to reference locations within an EPUB document.
class EpubCfiUtil {
  /// Generates a CFI for the current position in the EPUB.
  ///
  /// [book] is the EPUB book
  /// [chapterIndex] is the index of the current chapter
  /// [scrollPosition] is the scroll position within the chapter (0.0 to 1.0)
  static String? generateCfi({
    required EpubBook? book,
    required int chapterIndex,
    double scrollPosition = 0.0,
  }) {
    if (book == null ||
        chapterIndex < 0 ||
        chapterIndex >= book.Chapters!.length) {
      return null;
    }

    final chapter = book.Chapters![chapterIndex];
    final generator = EpubCfiGenerator();

    // Create the package document component
    final packageComponent = _generatePackageComponent(
      book,
      chapter,
      generator,
    );

    // Create a simple content document component based on scroll position
    // This is a simplified approach - for more precise targeting, you'd need
    // to identify the actual element at the scroll position
    final contentComponent = _generateContentComponentFromScroll(
      chapter,
      scrollPosition,
    );

    // Combine to create the complete CFI
    return generator.generateCompleteCFI([packageComponent, contentComponent]);
  }

  /// Extracts the chapter index from a CFI string.
  static int? getChapterIndexFromCfi(String? cfi, EpubBook book) {
    if (cfi == null || cfi.isEmpty) return null;

    try {
      // Parse the CFI
      final cfiFragment = EpubCfiParser().parse(cfi, 'fragment');
      if (cfiFragment.path?.localPath?.steps == null ||
          cfiFragment.path!.localPath!.steps!.isEmpty) {
        return null;
      }

      // Get the spine item reference
      final cfiStep = cfiFragment.path!.localPath!.steps!.first;
      String? idRef = cfiStep.idAssertion;

      // Find the chapter with this ID or filename
      for (int i = 0; i < book.Chapters!.length; i++) {
        final chapter = book.Chapters![i];
        if (chapter.Anchor == idRef ||
            (chapter.ContentFileName != null &&
                chapter.ContentFileName!.contains(idRef!))) {
          return i;
        }
      }

      return null;
    } catch (e) {
      // Silently handle the error and return null
      return null;
    }
  }

  /// Extracts the scroll position from a CFI string.
  static double? getScrollPositionFromCfi(
    String? cfi,
    EpubBook book,
    int chapterIndex,
  ) {
    if (cfi == null || cfi.isEmpty) return null;

    try {
      // This is a simplified implementation
      // For a more accurate implementation, you'd need to:
      // 1. Find the target element in the HTML
      // 2. Calculate its position relative to the chapter content
      // 3. Convert this to a scroll position percentage

      // For now, we'll extract a simple value from the CFI if possible
      final cfiFragment = EpubCfiParser().parse(cfi, 'fragment');
      if (cfiFragment.path?.localPath?.steps == null ||
          cfiFragment.path!.localPath!.steps!.length < 2) {
        return 0.0; // Default to top of chapter
      }

      // A very simple estimation based on steps - this is not accurate
      // but provides a starting point
      final steps = cfiFragment.path!.localPath!.steps!;
      if (steps.length > 1) {
        // Try to estimate position based on second step (content document step)
        final contentStep = steps[1];
        if (contentStep.stepValue != null) {
          // Convert step value to a relative position (very approximate)
          return contentStep.stepValue! / 100.0; // Arbitrary scaling
        }
      }

      return 0.0;
    } catch (e) {
      // Silently handle the error and return default
      return 0.0;
    }
  }

  // Helper methods
  static String? _generatePackageComponent(
    EpubBook book,
    EpubChapter chapter,
    EpubCfiGenerator generator,
  ) {
    final packageDocument = book.Schema!.Package;

    // Validate package document
    if (packageDocument == null) {
      return null;
    }

    // Find the spine index for this chapter
    int index = _getIdRefIndex(chapter, packageDocument);
    final int pos = (index + 1) * 2; // CFI position formula

    // Get the spine ID reference
    final String? spineIdRef = index >= 0
        ? packageDocument.Spine!.Items![index].IdRef
        : chapter.Anchor;

    // Format the package component
    return '/6/$pos[$spineIdRef]!';
  }

  static String _generateContentComponentFromScroll(
    EpubChapter chapter,
    double scrollPosition,
  ) {
    // For a simple implementation, we'll generate a basic content document component
    // In a more advanced implementation, you would:
    // 1. Parse the HTML content
    // 2. Find the element at the scroll position
    // 3. Generate a precise CFI path to that element

    // Simple implementation - just use a fixed path with the scroll position encoded
    // This is not standard CFI, but can be interpreted by our own code
    return '/4/2[@position=$scrollPosition]';
  }

  static int _getIdRefIndex(EpubChapter chapter, EpubPackage packageDocument) {
    final items = packageDocument.Spine!.Items!;
    int index = -1;
    int partIndex = -1;
    String? idRef = chapter.Anchor;

    if (chapter.Anchor == null) {
      // Use filename without extension as fallback
      idRef = _fileNameWithoutExtension(chapter.ContentFileName!);
    }

    for (var i = 0; i < items.length; i++) {
      if (idRef == items[i].IdRef) {
        index = i;
        break;
      }
      if (idRef!.contains(items[i].IdRef!)) {
        partIndex = i;
      }
    }

    return index >= 0 ? index : partIndex;
  }

  static String _fileNameWithoutExtension(String path) {
    return path.split('/').last.replaceFirst(RegExp(r'\.[^.]+$'), '');
  }
}
