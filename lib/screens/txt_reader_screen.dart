import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/txt_reader_service.dart';
import '../utils/txt_reader_utils.dart';

class TxtReaderScreen extends StatelessWidget {
  final String filePath;
  final String fileName;

  const TxtReaderScreen({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TxtReaderService(filePath),
      child: Consumer<TxtReaderService>(
        builder: (context, service, child) {
          return Scaffold(
            appBar: buildAppBar(context, service, fileName),
            body: buildBody(context, service),
          );
        },
      ),
    );
  }
}
