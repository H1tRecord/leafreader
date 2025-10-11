import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/pdf_reader_service.dart';
import '../utils/pdf_reader_utils.dart';

class PdfReaderScreen extends StatelessWidget {
  final String filePath;
  final String fileName;

  const PdfReaderScreen({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final service = PdfReaderService();
        // Initialize with file path to load saved annotations
        service.initWithFile(filePath);
        return service;
      },
      child: Consumer<PdfReaderService>(
        builder: (context, service, child) {
          return WillPopScope(
            // Save annotations when navigating back
            onWillPop: () async {
              await service.flushPendingChanges();
              return true;
            },
            child: Scaffold(
              appBar: buildAppBar(context, service, fileName),
              body: buildBody(context, service, filePath),
              bottomNavigationBar: service.showPageNavigation
                  ? buildBottomNavigationBar(context, service)
                  : null,
            ),
          );
        },
      ),
    );
  }
}
