import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/epub_reader_service.dart';
import '../utils/epub_reader_utils.dart';

class EpubReaderScreen extends StatelessWidget {
  final String filePath;
  final String fileName;

  const EpubReaderScreen({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EpubReaderService(filePath),
      child: Consumer<EpubReaderService>(
        builder: (context, service, child) {
          return PopScope(
            canPop: true,
            onPopInvoked: (didPop) async {
              if (didPop) {
                await service.savePositionOnExit();
              }
            },
            child: Scaffold(
              appBar: buildAppBar(context, service, fileName),
              body: buildBody(context, service),
            ),
          );
        },
      ),
    );
  }
}
