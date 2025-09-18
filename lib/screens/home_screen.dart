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
        title: _isSearching
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
            : const Text('LeafReader'),
        actions: [
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
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(
                context,
              ).pushNamed('/settings').then((_) => homeService.loadFiles());
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: buildBody(context, homeService),
      floatingActionButton: FloatingActionButton(
        onPressed: () => homeService.selectFolder(),
        tooltip: 'Change Folder',
        child: const Icon(Icons.folder),
      ),
    );
  }
}
