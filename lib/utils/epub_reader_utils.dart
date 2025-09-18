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
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Html(data: service.getChapterHtmlContent(index)),
      );
    },
    onPageChanged: (index) {
      service.goToChapter(index);
    },
  );
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
