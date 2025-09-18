import 'package:flutter/material.dart';
import 'package:epub_view/epub_view.dart';
import '../services/epub_reader_service.dart';
import '../utils/prefs_helper.dart';

PreferredSizeWidget buildAppBar(
  BuildContext context,
  EpubReaderService service,
  String fileName,
) {
  return AppBar(
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        if (!service.isLoading &&
            service.errorMessage == null &&
            service.epubController.currentValue != null)
          Text(
            buildChapterInfo(service),
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    ),
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1.0),
      child: Container(
        color: Theme.of(context).dividerColor.withAlpha(51), // ~0.2 alpha
        height: 1.0,
      ),
    ),
    actions: [
      IconButton(
        icon: const Icon(Icons.list),
        onPressed: !service.isLoading && service.errorMessage == null
            ? () => showChaptersDialog(context, service, fileName)
            : null,
        tooltip: 'Chapters',
      ),
      IconButton(
        icon: const Icon(Icons.settings),
        onPressed: !service.isLoading && service.errorMessage == null
            ? () => showReaderSettingsDialog(context, service)
            : null,
        tooltip: 'Reader Settings',
      ),
      IconButton(
        icon: const Icon(Icons.info_outline),
        onPressed: !service.isLoading && service.errorMessage == null
            ? () => showBookInfoDialog(context, service)
            : null,
        tooltip: 'Book Info',
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 60,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              service.errorMessage!.contains('EPUB3')
                  ? 'Unsupported EPUB Version'
                  : 'Failed to load EPUB file',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              service.errorMessage!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  return EpubView(
    controller: service.epubController,
    builders: EpubViewBuilders<DefaultBuilderOptions>(
      options: DefaultBuilderOptions(
        textStyle: TextStyle(
          height: 1.25,
          fontSize: service.fontSize,
          fontFamily: service.fontFamily == 'Default'
              ? null
              : service.fontFamily,
        ),
        paragraphPadding: const EdgeInsets.symmetric(horizontal: 16),
        chapterPadding: const EdgeInsets.all(8),
      ),
      chapterDividerBuilder: (_) => const Divider(),
    ),
    onChapterChanged: (value) => service.onChapterChanged(),
    onDocumentLoaded: (document) => service.onDocumentLoaded(document),
    onDocumentError: (error) => service.onDocumentError(error),
  );
}

String buildChapterInfo(EpubReaderService service) {
  final currentValue = service.epubController.currentValue;
  if (currentValue == null) return '';

  final chapters = service.epubController.tableOfContents();
  return '${currentValue.chapterNumber}/${chapters.length} • ${currentValue.progress.round()}%';
}

void showReaderSettingsDialog(BuildContext context, EpubReaderService service) {
  showModalBottomSheet(
    context: context,
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
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Font Size: ${service.fontSize.toStringAsFixed(1)}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Slider(
                          value: service.fontSize,
                          min: 10.0,
                          max: 30.0,
                          divisions: 20,
                          label: service.fontSize.toStringAsFixed(1),
                          onChanged: (value) {
                            setModalState(() {
                              service.updateFontSize(value);
                            });
                          },
                          onChangeEnd: (value) {
                            PrefsHelper.saveEpubFontSize(value);
                          },
                        ),
                      ],
                    ),
                  ),
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
                          value: service.fontFamily,
                          items: ['Default', 'Serif', 'Sans-serif']
                              .map(
                                (family) => DropdownMenuItem(
                                  value: family,
                                  child: Text(family),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              service.updateFontFamily(value);
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
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
  );
}

void showBookInfoDialog(BuildContext context, EpubReaderService service) {
  showModalBottomSheet(
    context: context,
    builder: (context) {
      return SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Book Information',
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
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: service.epubVersion.contains('3')
                            ? Colors.green.withOpacity(0.2)
                            : service.epubVersion.contains('2')
                            ? Colors.blue.withOpacity(0.2)
                            : Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'EPUB ${service.epubVersion}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: service.epubVersion.contains('3')
                              ? Colors.green.shade700
                              : service.epubVersion.contains('2')
                              ? Colors.blue.shade700
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: service.epubMetadata.entries
                      .map(
                        (entry) => ListTile(
                          title: Text(
                            entry.key,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            entry.value,
                            style: const TextStyle(fontSize: 16),
                          ),
                          dense: true,
                        ),
                      )
                      .toList(),
                ),
              ),
              if (service.epubVersion.contains('3'))
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service.epubVersion.contains('3')
                              ? 'EPUB 3 Optimizations Applied'
                              : 'EPUB 2 Compatibility Mode',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          service.epubVersion.contains('3')
                              ? 'Enhanced media support, accessibility features, and CSS3 styling applied.'
                              : 'Basic formatting and legacy compatibility mode enabled for older EPUB format.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.7,
    ),
  );
}

void showChaptersDialog(
  BuildContext context,
  EpubReaderService service,
  String fileName,
) {
  final chapters = service.epubController.tableOfContents();
  final currentValue = service.epubController.currentValue;

  showModalBottomSheet(
    context: context,
    builder: (context) {
      return SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Table of Contents',
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
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Book: $fileName',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 4),
              if (currentValue != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Current position: Chapter ${currentValue.chapterNumber} of ${chapters.length} • ${currentValue.progress.round()}% complete',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 8),
              const Divider(),
              chapters.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(child: Text('No chapters found')),
                    )
                  : Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: chapters.length,
                        itemBuilder: (context, index) {
                          final chapter = chapters[index];
                          final bool isCurrentChapter =
                              currentValue?.chapterNumber == index + 1;

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            title: Text(
                              chapter.title ?? 'Chapter ${index + 1}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: isCurrentChapter
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            subtitle: isCurrentChapter && currentValue != null
                                ? Text(
                                    'Current position: ${currentValue.progress.round()}% of chapter',
                                  )
                                : null,
                            leading: CircleAvatar(
                              backgroundColor: isCurrentChapter
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                              foregroundColor: isCurrentChapter
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                              child: Text('${index + 1}'),
                            ),
                            trailing: isCurrentChapter
                                ? Icon(
                                    Icons.bookmark,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  )
                                : null,
                            tileColor: isCurrentChapter
                                ? Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer.withAlpha(50)
                                : null,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            onTap: () {
                              service.epubController.scrollTo(
                                index: chapter.startIndex,
                                alignment: 0.0,
                                duration: const Duration(milliseconds: 300),
                              );
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
              const SizedBox(height: 8),
              if (currentValue != null && chapters.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.skip_previous),
                        label: const Text('Previous'),
                        onPressed: currentValue.chapterNumber > 1
                            ? () {
                                final prevChapter =
                                    chapters[currentValue.chapterNumber - 2];
                                service.epubController.scrollTo(
                                  index: prevChapter.startIndex,
                                  alignment: 0.0,
                                  duration: const Duration(milliseconds: 300),
                                );
                                Navigator.pop(context);
                              }
                            : null,
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.skip_next),
                        label: const Text('Next'),
                        onPressed: currentValue.chapterNumber < chapters.length
                            ? () {
                                final nextChapter =
                                    chapters[currentValue.chapterNumber];
                                service.epubController.scrollTo(
                                  index: nextChapter.startIndex,
                                  alignment: 0.0,
                                  duration: const Duration(milliseconds: 300),
                                );
                                Navigator.pop(context);
                              }
                            : null,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    },
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.7,
    ),
  );
}
