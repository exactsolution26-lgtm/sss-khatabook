import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

Future<void> shareFile(BuildContext context, Uint8List bytes, String name, String mime) async {
  final box = context.findRenderObject() as RenderBox?;
  await SharePlus.instance.share(ShareParams(
    files: [XFile.fromData(bytes, mimeType: mime)], fileNameOverrides: [name],
    sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
  ));
}
