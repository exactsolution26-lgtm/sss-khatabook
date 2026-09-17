import 'package:flutter/material.dart';

class SimpleInput extends StatelessWidget {
  final String? hintText;
  final String? label;
  final TextInputType keyboardType;
  final TextEditingController controller;
  final int maxLines;
  final String? Function(String?)? validator;

  const SimpleInput({
    super.key,
    this.hintText,
    this.label,
    this.keyboardType = TextInputType.text,
    required this.controller,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      minLines: maxLines == 1 ? 1 : null,
      validator: validator,
      decoration: InputDecoration(
        hintText: hintText,
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
