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
        child: Html(data: service.getChapterHtmlContent(index)),
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
