import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<({String name, Uint8List bytes})?> pickDocument() async {
  const channel = MethodChannel('edu.parsu.motopass/documents');
  final file = await channel.invokeMapMethod<String, Object>('pick');
  if (file == null) return null;
  return (name: file['name'] as String, bytes: file['bytes'] as Uint8List);
}

Future<bool> showPdf(BuildContext context, Uint8List bytes) async {
  const channel = MethodChannel('edu.parsu.motopass/documents');
  Future<Map<String, Object>> render(int page) async =>
      (await channel.invokeMapMethod<String, Object>('renderPdf', {
        'bytes': bytes,
        'page': page,
      }))!;

  var page = 0;
  var image = await render(page);
  var loading = false;
  String? error;
  if (!context.mounted) return false;
  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final count = image['count'] as int;
        Future<void> goTo(int index) async {
          setState(() {
            loading = true;
            error = null;
          });
          try {
            final rendered = await render(index);
            if (context.mounted) {
              setState(() {
                page = index;
                image = rendered;
              });
            }
          } on PlatformException {
            if (context.mounted) {
              setState(() => error = 'Could not display that page.');
            }
          } finally {
            if (context.mounted) setState(() => loading = false);
          }
        }

        return AlertDialog(
          title: Text('Page ${page + 1} of $count'),
          content: SizedBox(
            width: 480,
            height: 480,
            child: InteractiveViewer(
              child: Image.memory(image['image'] as Uint8List),
            ),
          ),
          actions: [
            if (error != null) Text(error!),
            if (page > 0)
              TextButton(
                onPressed: loading ? null : () => goTo(page - 1),
                child: const Text('Previous'),
              ),
            if (page + 1 < count)
              TextButton(
                onPressed: loading ? null : () => goTo(page + 1),
                child: const Text('Next'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    ),
  );
  return true;
}
