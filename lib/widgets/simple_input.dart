import '../core/localization/app_text.dart';
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
    validator: validator==null?null:(value){final error=validator!(value);return error==null?null:localizeUi(context,error);},
    maxLines: maxLines,
    decoration: InputDecoration(
      hintText: hintText==null?null:localizeUi(context,hintText!),
      label: label==null?null:AppText(label!),
      border: const OutlineInputBorder(),
    ),
  );
}
