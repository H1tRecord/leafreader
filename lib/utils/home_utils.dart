import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import '../services/home_service.dart';

IconData getFileIcon(String filePath) {
  final extension = path.extension(filePath).toLowerCase();

  switch (extension) {
    case '.pdf':
      return Icons.picture_as_pdf;
    case '.epub':
      return Icons.book;
    case '.txt':
      return Icons.description;
    default:
      return Icons.insert_drive_file;
  }
}

Widget buildBody(
  BuildContext context,
  HomeService homeService, [
  bool isGridView = false,
]) {
  if (homeService.isLoading) {
    return const Center(child: CircularProgressIndicator());
  }

  if (homeService.errorMessage != null) {
    return Center(
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
            homeService.errorMessage!,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => homeService.selectFolder(),
            icon: const Icon(Icons.folder),
            label: const Text('Select Folder'),
          ),
        ],
      ),
    );
  }

  if (homeService.files.isEmpty) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_books,
            size: 60,
            color: Theme.of(context).colorScheme.primary.withAlpha(128),
          ),
          const SizedBox(height: 16),
          Text('No books found', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Add TXT, EPUB, or PDF files to the selected folder',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Text('Current folder:', style: Theme.of(context).textTheme.bodySmall),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              homeService.selectedFolderPath ?? 'No folder selected',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  if (homeService.filteredFiles.isEmpty && homeService.files.isNotEmpty) {
    return RefreshIndicator(
      onRefresh: () => homeService.loadFiles(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 60,
                  color: Theme.of(context).colorScheme.primary.withAlpha(128),
                ),
                const SizedBox(height: 16),
                Text(
                  'No matching books found',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Try a different search term',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    homeService.searchController.clear();
                  },
                  child: const Text('Clear Search'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build sort indicator text
  String getSortText(HomeService homeService) {
    String sortField = '';
    switch (homeService.sortOption) {
      case SortOption.name:
        sortField = 'Name';
        break;
      case SortOption.date:
        sortField = 'Date Modified';
        break;
      case SortOption.type:
        sortField = 'File Type';
        break;
    }
    final direction = homeService.sortAscending ? 'Ascending' : 'Descending';
    return 'Sorted by: $sortField ($direction)';
  }

  return Column(
    children: [
      Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.folder_outlined,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Library Location',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => homeService.selectFolder(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Change',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              homeService.selectedFolderPath ?? "No folder selected",
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
      Expanded(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => homeService.loadFiles(),
                child: homeService.filteredFiles.isEmpty
                    ? const Center(child: Text("No books found."))
                    : buildFileView(context, homeService, isGridView),
              ),
            ),
            // Sort indicator
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              width: double.infinity,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey.shade800
                  : Colors.grey.shade200,
              child: Text(
                getSortText(homeService),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey.shade300
                      : Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

Widget buildFileView(
  BuildContext context,
  HomeService homeService,
  bool isGridView,
) {
  return isGridView
      ? buildGridView(context, homeService)
      : buildListView(context, homeService);
}

Widget buildListView(BuildContext context, HomeService homeService) {
  return ListView.builder(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(12),
    itemCount: homeService.filteredFiles.length,
    itemBuilder: (context, index) {
      final file = homeService.filteredFiles[index];
      final fileName = path.basename(file.path);
      final fileExtension = path.extension(file.path).toLowerCase();

      // Get last modified date
      final fileInfo = File(file.path);
      final lastModified = fileInfo.lastModifiedSync();
      final formattedDate =
          '${lastModified.day}/${lastModified.month}/${lastModified.year}';

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          tileColor: homeService.isFileSelected(file) 
              ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4)
              : Theme.of(context).colorScheme.surface,
          onTap: () {
            if (homeService.isMultiSelectMode) {
              homeService.toggleFileSelection(file);
            } else {
              homeService.openFile(context, file.path);
            }
          },
          onLongPress: () {
            if (!homeService.isMultiSelectMode) {
              homeService.toggleMultiSelectMode();
              homeService.toggleFileSelection(file);
            }
          },
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                getFileIcon(file.path),
                color: _getFileColor(context, fileExtension),
                size: 30,
              ),
              if (homeService.isMultiSelectMode && homeService.isFileSelected(file))
                Positioned(
                  bottom: -4,
                  right: -4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 12,
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            fileName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getFileColor(context, fileExtension).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  fileExtension.substring(1).toUpperCase(),
                  style: TextStyle(
                    color: _getFileColor(context, fileExtension),
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.calendar_today_outlined,
                size: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              const SizedBox(width: 4),
              Text(
                formattedDate,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
          trailing: PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            onSelected: (value) {
              if (value == 'delete') {
                homeService.deleteFile(context, file);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    const Text('Delete'),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// Helper function to get color based on file type
Color _getFileColor(BuildContext context, String extension) {
  switch (extension.toLowerCase()) {
    case '.pdf':
      return Colors.red;
    case '.epub':
      return Colors.green;
    case '.txt':
      return Colors.blue;
    default:
      return Theme.of(context).colorScheme.primary;
  }
}

// Progress indicator has been removed

Widget buildGridView(BuildContext context, HomeService homeService) {
  // Calculate cross axis count based on screen width
  final width = MediaQuery.of(context).size.width;
  final crossAxisCount = width > 600 ? 3 : 2;

  return GridView.builder(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(12),
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount,
      childAspectRatio: 0.75,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
    ),
    itemCount: homeService.filteredFiles.length,
    itemBuilder: (context, index) {
      final file = homeService.filteredFiles[index];
      final fileName = path.basename(file.path);
      final fileExtension = path.extension(file.path).toLowerCase();

      // Get last modified date
      final fileInfo = File(file.path);
      final lastModified = fileInfo.lastModifiedSync();
      final formattedDate =
          '${lastModified.day}/${lastModified.month}/${lastModified.year}';

      return Card(
        elevation: 1,
        color: homeService.isFileSelected(file) 
            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4)
            : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            InkWell(
              onTap: () {
                if (homeService.isMultiSelectMode) {
                  homeService.toggleFileSelection(file);
                } else {
                  homeService.openFile(context, file.path);
                }
              },
              onLongPress: () {
                if (!homeService.isMultiSelectMode) {
                  homeService.toggleMultiSelectMode();
                  homeService.toggleFileSelection(file);
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Icon section
                  Expanded(
                    flex: 3,
                    child: Center(
                      child: Icon(
                        getFileIcon(file.path),
                        color: _getFileColor(context, fileExtension),
                        size: 48,
                      ),
                    ),
                  ),
                  // Info section
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fileName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _getFileColor(
                                    context,
                                    fileExtension,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  fileExtension.substring(1).toUpperCase(),
                                  style: TextStyle(
                                    color: _getFileColor(
                                      context,
                                      fileExtension,
                                    ),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                formattedDate,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                          // No progress indicator
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Show selection checkmark
            if (homeService.isMultiSelectMode && homeService.isFileSelected(file))
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.check,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 18,
                  ),
                ),
              ),
              
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
                child: PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.7),
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  onSelected: (value) {
                    if (value == 'delete') {
                      homeService.deleteFile(context, file);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          const Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
