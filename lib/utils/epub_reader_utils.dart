import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import '../services/epub_reader_service.dart';

PreferredSizeWidget buildAppBar(
  BuildContext context,
  EpubReaderService service,
  String fileName,
) {
  return AppBar(
    title: Text(fileName),
    actions: [
      IconButton(
        icon: const Icon(Icons.format_size),
        onPressed: () => showFontSettingsDialog(context, service),
      ),
      IconButton(
        icon: const Icon(Icons.list),
        onPressed: () => showChaptersDialog(context, service),
      ),
    ],
  );
}

Widget buildBody(BuildContext context, EpubReaderService service) {
  if (service.isLoading) {
    return const Center(child: CircularProgressIndicator());
  }

  if (service.errorMessage != null) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(service.errorMessage!),
      ),
    );
  }

  return PageView.builder(
    controller: service.pageController,
    itemCount: service.book?.Chapters?.length ?? 0,
    itemBuilder: (context, index) {
      // Use a custom scroll controller for each chapter
      // to track position within the chapter
      final scrollController = ScrollController(
        // Initialize with saved position if it's the current chapter
        initialScrollOffset: index == service.currentChapterIndex
            ? service.scrollPosition *
                  _estimateContentHeight(context, service, index)
            : 0.0,
      );

      // Add listener to update position when scrolling
      scrollController.addListener(() {
        if (index == service.currentChapterIndex &&
            scrollController.hasClients) {
          final maxScroll = scrollController.position.maxScrollExtent;
          if (maxScroll > 0) {
            // Calculate relative position (0.0 to 1.0)
            final position = scrollController.offset / maxScroll;
            service.updateScrollPosition(position);
          }
        }
      });

      return SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.all(16.0),
        child: Html(
          data: service.getChapterHtmlContent(index),
          style: {
            // Apply font family and size to all text elements
            "body": Style(
              fontFamily: _mapFontFamilyToSystem(service.fontFamily),
              fontSize: FontSize(service.fontSize),
            ),
            "p": Style(
              fontFamily: _mapFontFamilyToSystem(service.fontFamily),
              fontSize: FontSize(service.fontSize),
            ),
            "div": Style(
              fontFamily: _mapFontFamilyToSystem(service.fontFamily),
              fontSize: FontSize(service.fontSize),
            ),
            "span": Style(
              fontFamily: _mapFontFamilyToSystem(service.fontFamily),
              fontSize: FontSize(service.fontSize),
            ),
            // Add other elements as needed
          },
        ),
      );
    },
    onPageChanged: (index) {
      service.goToChapter(index);
    },
  );
}

// Helper function to estimate content height for scroll positioning
double _estimateContentHeight(
  BuildContext context,
  EpubReaderService service,
  int index,
) {
  // This is a rough estimation based on content length
  // A more accurate approach would involve measuring the actual rendered content
  final content = service.getChapterHtmlContent(index);
  // Assume a basic ratio of content length to height (adjust as needed)
  return content.length * 0.5;
}

void showChaptersDialog(BuildContext context, EpubReaderService service) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Chapters'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            itemCount: service.book?.Chapters?.length ?? 0,
            itemBuilder: (context, index) {
              final chapter = service.book!.Chapters![index];
              return ListTile(
                title: Text(chapter.Title ?? 'Chapter ${index + 1}'),
                onTap: () {
                  service.goToChapter(index);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      );
    },
  );
}

// Helper function to map font family names to system font families
String? _mapFontFamilyToSystem(String fontName) {
  switch (fontName) {
    case 'Serif':
      return 'serif';
    case 'Sans-serif':
      return 'sans-serif';
    case 'Default':
    default:
      return null; // Use the default system font
  }
}

void showFontSettingsDialog(BuildContext context, EpubReaderService service) {
  // Available font families that match the app's settings
  final availableFonts = ['Default', 'Serif', 'Sans-serif'];

  // Font size adjustment values
  double tempFontSize = service.fontSize;
  String tempFontFamily = service.fontFamily;

  // Make sure the current font family is in the available fonts list
  if (!availableFonts.contains(tempFontFamily)) {
    tempFontFamily =
        'Default'; // Fallback to default if current font isn't in the list
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Reader Settings',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                  ),
                  const Divider(),

                  // Font Size
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Font Size: ${tempFontSize.toStringAsFixed(1)}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Slider(
                          value: tempFontSize,
                          min: 10.0,
                          max: 30.0,
                          divisions: 20,
                          label: tempFontSize.toStringAsFixed(1),
                          onChanged: (value) {
                            setModalState(() {
                              tempFontSize = value;
                            });
                          },
                          onChangeEnd: (value) async {
                            await service.updateFontSize(value);
                          },
                        ),
                      ],
                    ),
                  ),

                  // Font Family
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Font Family',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: tempFontFamily,
                          items: availableFonts
                              .map(
                                (family) => DropdownMenuItem(
                                  value: family,
                                  child: Text(family),
                                ),
                              )
                              .toList(),
                          onChanged: (value) async {
                            if (value != null) {
                              setModalState(() {
                                tempFontFamily = value;
                              });
                              await service.updateFontFamily(value);
                            }
                          },
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
