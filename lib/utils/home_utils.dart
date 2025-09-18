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

Widget buildBody(BuildContext context, HomeService homeService) {
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

  return Column(
    children: [
      Container(
        padding: const EdgeInsets.all(8.0),
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withAlpha(77),
        width: double.infinity,
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Folder: ${homeService.selectedFolderPath ?? "None"}',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (homeService.filteredFiles.length != homeService.files.length)
              Text(
                '${homeService.filteredFiles.length} of ${homeService.files.length} books',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: () => homeService.loadFiles(),
          child: homeService.filteredFiles.isEmpty
              ? const Center(child: Text("No books found."))
              : buildFileView(
                  context,
                  homeService,
                  false,
                ), // Default to list view
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
    padding: const EdgeInsets.all(8),
    itemCount: homeService.filteredFiles.length,
    itemBuilder: (context, index) {
      final file = homeService.filteredFiles[index];
      final fileName = path.basename(file.path);
      final fileExtension = path.extension(file.path).toLowerCase();

      return Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: ListTile(
          leading: Icon(
            getFileIcon(file.path),
            color: Theme.of(context).colorScheme.primary,
            size: 36,
          ),
          title: Text(
            fileName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            'Type: ${fileExtension.substring(1).toUpperCase()}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') {
                homeService.deleteFile(context, file);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete),
                  title: Text('Delete'),
                ),
              ),
            ],
          ),
          onTap: () {
            homeService.openFile(context, file.path);
          },
        ),
      );
    },
  );
}

Widget buildGridView(BuildContext context, HomeService homeService) {
  return GridView.builder(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(8),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      childAspectRatio: 0.8,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
    ),
    itemCount: homeService.filteredFiles.length,
    itemBuilder: (context, index) {
      final file = homeService.filteredFiles[index];
      final fileName = path.basename(file.path);
      final fileExtension = path.extension(file.path).toLowerCase();

      return Card(
        elevation: 3,
        child: Stack(
          children: [
            InkWell(
              onTap: () {
                homeService.openFile(context, file.path);
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 3,
                    child: Center(
                      child: Icon(
                        getFileIcon(file.path),
                        color: Theme.of(context).colorScheme.primary,
                        size: 50,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          Text(
                            fileName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            fileExtension.substring(1).toUpperCase(),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') {
                    homeService.deleteFile(context, file);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete),
                      title: Text('Delete'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
