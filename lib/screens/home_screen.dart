import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/home_service.dart';
import '../utils/home_utils.dart';

const String _logoAssetPath = 'assets/Leaf_Reader_Logo.png';

enum _HomeMenuAction { sortName, sortDate, sortType, settings }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isSearching = false;
  bool _isGridView = false;

  @override
  Widget build(BuildContext context) {
    final homeService = Provider.of<HomeService>(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: homeService.isMultiSelectMode
            ? Text('${homeService.selectedCount} selected')
            : (_isSearching
                  ? TextField(
                      controller: homeService.searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search files...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withAlpha(153),
                        ),
                      ),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      onSubmitted: (_) {},
                    )
                  : Row(
                      children: [
                        Image.asset(
                          _logoAssetPath,
                          height: 32,
                          width: 32,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.menu_book,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Leaf Reader',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    )),
        leading: homeService.isMultiSelectMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => homeService.toggleMultiSelectMode(),
                tooltip: 'Cancel Selection',
              )
            : null,
        actions: homeService.isMultiSelectMode
            ? [
                IconButton(
                  icon: const Icon(Icons.select_all),
                  onPressed: () {
                    // Select all files functionality
                    for (var file in homeService.filteredFiles) {
                      if (!homeService.isFileSelected(file)) {
                        homeService.toggleFileSelection(file);
                      }
                    }
                  },
                  tooltip: 'Select All',
                ),
                IconButton(
                  icon: const Icon(Icons.flip_to_back),
                  onPressed: () {
                    homeService.inverseSelection();
                  },
                  tooltip: 'Inverse Selection',
                ),
                // Show rename button only when exactly one file is selected
                if (homeService.selectedCount == 1)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => homeService.renameSelectedFile(context),
                    tooltip: 'Rename Selected',
                  ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: homeService.selectedCount > 0
                      ? () => homeService.deleteSelectedFiles(context)
                      : null,
                  tooltip: 'Delete Selected',
                ),
              ]
            : [
                IconButton(
                  icon: Icon(_isSearching ? Icons.close : Icons.search),
                  onPressed: () {
                    setState(() {
                      _isSearching = !_isSearching;
                      if (!_isSearching) {
                        homeService.searchController.clear();
                      }
                    });
                  },
                  tooltip: _isSearching ? 'Cancel Search' : 'Search',
                ),
                IconButton(
                  icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
                  onPressed: () {
                    setState(() {
                      _isGridView = !_isGridView;
                    });
                  },
                  tooltip: _isGridView ? 'List View' : 'Grid View',
                ),
                PopupMenuButton<_HomeMenuAction>(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'More Options',
                  onSelected: (action) {
                    switch (action) {
                      case _HomeMenuAction.sortName:
                        homeService.setSortOption(SortOption.name);
                        break;
                      case _HomeMenuAction.sortDate:
                        homeService.setSortOption(SortOption.date);
                        break;
                      case _HomeMenuAction.sortType:
                        homeService.setSortOption(SortOption.type);
                        break;
                      case _HomeMenuAction.settings:
                        Navigator.of(context)
                            .pushNamed('/settings')
                            .then((_) => homeService.loadFiles());
                        break;
                    }
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<_HomeMenuAction>>[
                        PopupMenuItem<_HomeMenuAction>(
                          value: _HomeMenuAction.sortName,
                          child: Row(
                            children: [
                              const Text('Sort by Name'),
                              const Spacer(),
                              if (homeService.sortOption == SortOption.name)
                                Icon(
                                  homeService.sortAscending
                                      ? Icons.arrow_upward
                                      : Icons.arrow_downward,
                                  size: 16,
                                ),
                            ],
                          ),
                        ),
                        PopupMenuItem<_HomeMenuAction>(
                          value: _HomeMenuAction.sortDate,
                          child: Row(
                            children: [
                              const Text('Sort by Date'),
                              const Spacer(),
                              if (homeService.sortOption == SortOption.date)
                                Icon(
                                  homeService.sortAscending
                                      ? Icons.arrow_upward
                                      : Icons.arrow_downward,
                                  size: 16,
                                ),
                            ],
                          ),
                        ),
                        PopupMenuItem<_HomeMenuAction>(
                          value: _HomeMenuAction.sortType,
                          child: Row(
                            children: [
                              const Text('Sort by File Type'),
                              const Spacer(),
                              if (homeService.sortOption == SortOption.type)
                                Icon(
                                  homeService.sortAscending
                                      ? Icons.arrow_upward
                                      : Icons.arrow_downward,
                                  size: 16,
                                ),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem<_HomeMenuAction>(
                          value: _HomeMenuAction.settings,
                          child: Row(
                            children: const [
                              Icon(Icons.settings, size: 18),
                              SizedBox(width: 12),
                              Text('Settings'),
                            ],
                          ),
                        ),
                      ],
                ),
              ],
      ),
      body: buildBody(context, homeService, _isGridView),
    );
  }
}
