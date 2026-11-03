import 'package:flutter/material.dart';

class SimpleInput extends StatelessWidget {
  final String? hintText;
  final String? label;
  final TextInputType keyboardType;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final int maxLines;

  const SimpleInput({
    super.key,
    this.hintText,
    this.label,
    this.keyboardType = TextInputType.text,
    required this.controller,
    this.validator,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    validator: validator,
    maxLines: maxLines,
    decoration: InputDecoration(
      hintText: hintText,
      labelText: label,
      border: const OutlineInputBorder(),
    ),
  );
}
