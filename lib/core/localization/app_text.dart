import 'package:flutter/material.dart';
import '../../features/settings/app_settings.dart';
import 'ui_translations.dart';

String localizeUi(BuildContext context,String value) =>
    SettingsScope.maybeOf(context)?.language.name=='hindi' ? uiTranslations[value]??value : value;

/// Translate UI labels only. Customer data and financial values stay untouched.
class AppText extends StatelessWidget {
  const AppText(this.english,{super.key,this.style,this.textAlign,this.maxLines,this.overflow,this.softWrap,this.textDirection,this.semanticsLabel});
  final String english;
  final TextStyle? style;final TextAlign? textAlign;final int? maxLines;
  final TextOverflow? overflow;final bool? softWrap;final TextDirection? textDirection;final String? semanticsLabel;
  @override Widget build(BuildContext context){
    final value=localizeUi(context,english);
    return Text(value,style:style,textAlign:textAlign,maxLines:maxLines,overflow:overflow,softWrap:softWrap,
      textDirection:textDirection,semanticsLabel:semanticsLabel);
  }
}
