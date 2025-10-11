import 'package:flutter/material.dart';
import '../services/txt_reader_service.dart';

PreferredSizeWidget buildAppBar(
  BuildContext context,
  TxtReaderService service,
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
          hintText: 'Search in text',
          border: InputBorder.none,
          hintStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
          ),
        ),
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      ),
      actions: [
        if (service.searchController.text.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => service.clearSearch(),
          ),
      ],
    );
  }

  return AppBar(
    title: Text(fileName),
    actions: [
      IconButton(
        icon: const Icon(Icons.search),
        tooltip: 'Search text',
        onPressed: () => service.toggleSearch(),
      ),
      IconButton(
        icon: const Icon(Icons.settings),
        tooltip: 'Reader Settings',
        onPressed: () => showReaderSettingsDialog(context, service),
      ),
    ],
  );
}

Widget buildBody(BuildContext context, TxtReaderService service) {
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
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error Loading Text File',
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
      Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          controller: service.scrollController,
          child: RichText(text: buildTextSpan(context, service)),
        ),
      ),
      if (service.isSearching && service.searchResults.isNotEmpty)
        buildSearchNavigationPanel(context, service),
    ],
  );
}

TextSpan buildTextSpan(BuildContext context, TxtReaderService service) {
  if (service.content == null) {
    return const TextSpan(text: '');
  }

  final fontFamily = _resolveFontFamily(service.fontFamily);

  if (!service.isSearching || service.searchResults.isEmpty) {
    return TextSpan(
      text: service.content,
      style: _readerTextStyle(context, service, fontFamily),
    );
  }

  final spans = <TextSpan>[];
  int lastEnd = 0;

  for (int i = 0; i < service.searchResults.length; i++) {
    final start = service.searchResults[i];
    final end = start + service.searchController.text.length;

    if (start > lastEnd) {
      spans.add(
        TextSpan(
          text: service.content!.substring(lastEnd, start),
          style: _readerTextStyle(context, service, fontFamily),
        ),
      );
    }

    spans.add(
      TextSpan(
        text: service.content!.substring(start, end),
        style: _readerTextStyle(
          context,
          service,
          fontFamily,
          color: i == service.currentSearchIndex
              ? Colors.black
              : Theme.of(context).brightness == Brightness.light
              ? Colors.black
              : Colors.white,
          backgroundColor: i == service.currentSearchIndex
              ? Colors.orange.withAlpha(179)
              : Colors.yellow.withAlpha(77),
          fontWeight: i == service.currentSearchIndex ? FontWeight.bold : null,
        ),
      ),
    );

    lastEnd = end;
  }

  if (lastEnd < service.content!.length) {
    spans.add(
      TextSpan(
        text: service.content!.substring(lastEnd),
        style: _readerTextStyle(context, service, fontFamily),
      ),
    );
  }

  return TextSpan(children: spans);
}

FontFamily _resolveFontFamily(String selection) {
  switch (selection) {
    case 'Serif':
      return FontFamily.serif;
    case 'Sans-serif':
      return FontFamily.sansSerif;
    case 'Monospace':
      return FontFamily.monospace;
    case 'Roboto':
      return FontFamily.roboto;
    case 'Helvetica':
      return FontFamily.helvetica;
    case 'Georgia':
      return FontFamily.georgia;
    case 'Times New Roman':
      return FontFamily.timesNewRoman;
    case 'Courier New':
      return FontFamily.courierNew;
    default:
      return FontFamily.default_;
  }
}

TextStyle _readerTextStyle(
  BuildContext context,
  TxtReaderService service,
  FontFamily fontFamily, {
  Color? color,
  FontWeight? fontWeight,
  Color? backgroundColor,
}) {
  final resolvedColor = color ?? Theme.of(context).textTheme.bodyLarge?.color;
  final familyName = fontFamily.name.isEmpty ? null : fontFamily.name;
  return TextStyle(
    fontSize: service.fontSize,
    fontFamily: familyName,
    fontFamilyFallback: fontFamily.fallback,
    color: resolvedColor,
    fontWeight: fontWeight,
    backgroundColor: backgroundColor,
  );
}

void showReaderSettingsDialog(BuildContext context, TxtReaderService service) {
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
                          'Text Reader Settings',
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
                          min: 8.0,
                          max: 32.0,
                          divisions: 24,
                          label: service.fontSize.toStringAsFixed(1),
                          onChanged: (value) {
                            setModalState(() {
                              service.setFontSize(value);
                            });
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
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setModalState(() {
                            service.resetToDefaults();
                          });
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset to Defaults'),
                      ),
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
                          items:
                              const [
                                    'Default',
                                    'Serif',
                                    'Sans-serif',
                                    'Monospace',
                                    'Roboto',
                                    'Helvetica',
                                    'Georgia',
                                    'Times New Roman',
                                    'Courier New',
                                  ]
                                  .map(
                                    (family) => DropdownMenuItem(
                                      value: family,
                                      child: Text(family),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setModalState(() {
                                service.setFontFamily(value);
                              });
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

Widget buildSearchNavigationPanel(
  BuildContext context,
  TxtReaderService service,
) {
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
                'Result ${service.currentSearchIndex + 1} of ${service.searchResults.length}',
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
                    onPressed: () => service.previousSearchResult(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down),
                    tooltip: 'Next result',
                    onPressed: () => service.nextSearchResult(),
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
