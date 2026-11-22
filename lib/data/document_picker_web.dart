import 'package:flutter/material.dart';

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'student_api.dart';

Future<({String name, Uint8List bytes})?> pickDocument() async {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.pdf,.png,.jpg,.jpeg'
    ..setAttribute('hidden', '');
  final picked = Completer<web.File?>();
  input.addEventListener(
    'change',
    ((web.Event _) {
      if (!picked.isCompleted) picked.complete(input.files?.item(0));
    }).toJS,
    web.AddEventListenerOptions(once: true),
  );
  input.addEventListener(
    'cancel',
    ((web.Event _) {
      if (!picked.isCompleted) picked.complete(null);
    }).toJS,
    web.AddEventListenerOptions(once: true),
  );
  web.document.body?.append(input);
  final web.File? file;
  try {
    input.click();
    file = await picked.future;
  } finally {
    input.remove();
  }
  if (file == null) return null;
  if (file.size < 1 || file.size > 5 * 1024 * 1024) {
    throw const StudentApiException('Choose a file between 1 byte and 5 MB.');
  }
  final bytes = (await file.arrayBuffer().toDart).toDart.asUint8List();
  return (name: file.name, bytes: bytes);
}

Future<bool> showPdf(BuildContext context, Uint8List bytes) async {
  final pdf = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/pdf'),
  );
  final url = web.URL.createObjectURL(pdf);
  try {
    final opened = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Review PDF'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final link = web.HTMLAnchorElement()
                ..href = url
                ..target = '_blank'
                ..rel = 'noopener noreferrer';
              link.click();
              Navigator.pop(context, true);
            },
            child: const Text('Open in new tab'),
          ),
        ],
      ),
    );
    return opened == true;
  } finally {
    Timer(const Duration(minutes: 1), () => web.URL.revokeObjectURL(url));
  }
}
