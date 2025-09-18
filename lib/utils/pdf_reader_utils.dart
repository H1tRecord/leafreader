import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../services/pdf_reader_service.dart';

PreferredSizeWidget buildAppBar(
  BuildContext context,
  PdfReaderService service,
  String fileName,
) {
  if (service.isSearching) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => service.toggleSearch(),
      ),
      title: TextField(
        controller: service.searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Search in PDF',
          border: InputBorder.none,
          hintStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        onChanged: (text) => service.onSearchTextChanged(text),
        onSubmitted: (value) {
          if (value.isNotEmpty) {
            service.startSearch(value);
          }
        },
      ),
      actions: [
        if (service.searchController.text.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => service.clearSearch(),
          ),
        if (service.searchController.text.isNotEmpty &&
            !service.searchResult.hasResult)
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () {
              if (service.searchController.text.isNotEmpty) {
                service.startSearch(service.searchController.text);
              }
            },
          ),
      ],
    );
  }

  return AppBar(
    title: Text(fileName),
    actions: [
      IconButton(
        icon: const Icon(Icons.search),
        tooltip: 'Search PDF',
        onPressed: () => service.toggleSearch(),
      ),
      IconButton(
        icon: const Icon(Icons.save),
        tooltip: 'Save annotations',
        onPressed: () async {
          await service.saveAnnotations();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Annotations saved'),
              duration: Duration(seconds: 1),
            ),
          );
        },
      ),
      IconButton(
        icon: service.pageLayoutMode == PdfPageLayoutMode.continuous
            ? const Icon(Icons.view_agenda_outlined)
            : const Icon(Icons.auto_stories),
        tooltip: 'Toggle page layout',
        onPressed: () => service.togglePageLayoutMode(),
      ),
      PopupMenuButton<String>(
        tooltip: 'More options',
        onSelected: (value) => service.handleMenuSelection(value),
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'zoom_in',
            child: Row(
              children: [
                Icon(Icons.zoom_in),
                SizedBox(width: 8),
                Text('Zoom in'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'zoom_out',
            child: Row(
              children: [
                Icon(Icons.zoom_out),
                SizedBox(width: 8),
                Text('Zoom out'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'page_nav',
            child: Row(
              children: [
                Icon(Icons.swap_vert),
                SizedBox(width: 8),
                Text('Toggle page navigation'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'scroll_head',
            child: Row(
              children: [
                Icon(Icons.view_sidebar),
                SizedBox(width: 8),
                Text('Toggle scroll head'),
              ],
            ),
          ),
        ],
      ),
    ],
  );
}

Widget buildBody(
  BuildContext context,
  PdfReaderService service,
  String filePath,
) {
  if (service.errorMessage != null) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error Loading PDF',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(service.errorMessage!, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  return Stack(
    children: [
      SfPdfViewer.file(
        File(filePath),
        key: service.pdfViewerKey,
        controller: service.pdfViewerController,
        canShowScrollHead: service.showScrollHead,
        canShowScrollStatus: true,
        canShowPaginationDialog: true,
        pageLayoutMode: service.pageLayoutMode,
        enableTextSelection: true,
        onTextSelectionChanged: (PdfTextSelectionChangedDetails details) {
          if (details.selectedText != null &&
              details.selectedText!.isNotEmpty) {
            debugPrint('Selected text: ${details.selectedText}');
          }
        },
        onPageChanged: (PdfPageChangedDetails details) {
          // The listener in the service will handle the update
        },
        // Listen to document loaded to mark annotations as modified
        onDocumentLoaded: (PdfDocumentLoadedDetails details) {
          // We need to set up a listener for annotation changes
          // Since we can't directly listen to annotation changes,
          // we'll mark them as modified when the user interacts with text
          WidgetsBinding.instance.addPostFrameCallback((_) {
            service.pdfViewerController.addListener(() {
              // This is a crude way to detect changes, but we don't have direct annotation change events
              if (service.pdfViewerController.annotationMode !=
                  PdfAnnotationMode.none) {
                service.onAnnotationsChanged();
              }
            });
          });
        },
      ),
      buildSearchResultsPanel(context, service),
    ],
  );
}

Widget buildBottomNavigationBar(
  BuildContext context,
  PdfReaderService service,
) {
  final int currentPage = service.pdfViewerController.pageNumber;
  final int totalPages = service.pdfViewerController.pageCount;

  return BottomAppBar(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_left),
            tooltip: 'Previous page',
            onPressed: currentPage > 1
                ? () => service.pdfViewerController.previousPage()
                : null,
          ),
          GestureDetector(
            onTap: () => showPageNavigationDialog(context, service),
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: 8.0,
                horizontal: 12.0,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16.0),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: Text(
                'Page $currentPage of $totalPages',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_right),
            tooltip: 'Next page',
            onPressed: currentPage < totalPages
                ? () => service.pdfViewerController.nextPage()
                : null,
          ),
        ],
      ),
    ),
  );
}

Future<void> showPageNavigationDialog(
  BuildContext context,
  PdfReaderService service,
) async {
  final int currentPage = service.pdfViewerController.pageNumber;
  final int totalPages = service.pdfViewerController.pageCount;
  final TextEditingController pageController = TextEditingController(
    text: currentPage.toString(),
  );

  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Go to page'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Enter page number (1-$totalPages)',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: pageController,
            keyboardType: TextInputType.number,
            autofocus: true,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final int? pageNumber = int.tryParse(pageController.text);
            if (pageNumber != null &&
                pageNumber > 0 &&
                pageNumber <= totalPages) {
              service.pdfViewerController.jumpToPage(pageNumber);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Please enter a valid page number (1-$totalPages)',
                  ),
                ),
              );
            }
            Navigator.pop(context);
          },
          child: const Text('Go'),
        ),
      ],
    ),
  );
}

Widget buildSearchResultsPanel(BuildContext context, PdfReaderService service) {
  if (!service.isSearching || !service.searchResult.hasResult) {
    return const SizedBox.shrink();
  }

  return Positioned(
    bottom: 0,
    left: 0,
    right: 0,
    child: Material(
      elevation: 4,
      child: Container(
        color: Theme.of(context).colorScheme.surface,
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Result ${service.searchResult.currentInstanceIndex} of ${service.searchResult.totalInstanceCount}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_up),
                    tooltip: 'Previous result',
                    onPressed: service.searchResult.hasResult
                        ? () => service.searchResult.previousInstance()
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down),
                    tooltip: 'Next result',
                    onPressed: service.searchResult.hasResult
                        ? () => service.searchResult.nextInstance()
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
