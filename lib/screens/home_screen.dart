import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/home_service.dart';
import '../utils/home_utils.dart';

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
        title: homeService.isMultiSelectMode
            ? Text('${homeService.selectedCount} selected')
            : (_isSearching
                  ? TextField(
                      controller: homeService.searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search books...',
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
                  : const Text('LeafReader')),
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
                PopupMenuButton<SortOption>(
                  icon: const Icon(Icons.sort),
                  tooltip: 'Sort By',
                  onSelected: (SortOption option) {
                    homeService.setSortOption(option);
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<SortOption>>[
                        PopupMenuItem<SortOption>(
                          value: SortOption.name,
                          child: Row(
                            children: [
                              const Text('Name'),
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
                        PopupMenuItem<SortOption>(
                          value: SortOption.date,
                          child: Row(
                            children: [
                              const Text('Date Modified'),
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
                        PopupMenuItem<SortOption>(
                          value: SortOption.type,
                          child: Row(
                            children: [
                              const Text('File Type'),
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
                      ],
                ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () {
                    Navigator.of(context)
                        .pushNamed('/settings')
                        .then((_) => homeService.loadFiles());
                  },
                  tooltip: 'Settings',
                ),
              ],
      ),
      body: buildBody(context, homeService, _isGridView),
    );
  }
}
