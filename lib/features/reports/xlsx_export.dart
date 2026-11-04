import 'dart:typed_data';
import 'package:archive/archive.dart';

/// Small Open XML workbook writer. User strings are inline text, never formulas,
/// paths or macro content. Numeric amounts remain numeric in Excel.
class XlsxExport {
  static String _xml(String text) => text.replaceAll(RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f]'), '')
    .replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;').replaceAll("'", '&apos;');
  static String _column(int index) {
    var value = index + 1, result = '';
    while (value > 0) {value--; result = '${String.fromCharCode(65 + value % 26)}$result'; value ~/= 26;}
    return result;
  }
  static Uint8List write(List<List<Object?>> rows) {
    final sheet = StringBuffer('<?xml version="1.0" encoding="UTF-8"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>');
    for (var r = 0; r < rows.length; r++) {
      sheet.write('<row r="${r + 1}">');
      for (var c = 0; c < rows[r].length; c++) {
        final value = rows[r][c], cell = '${_column(c)}${r + 1}';
        if (value is num) {
          if (!value.isFinite) throw ArgumentError('Non-finite spreadsheet amount');
          sheet.write('<c r="$cell" s="1"><v>$value</v></c>');
        } else {
          sheet.write('<c r="$cell" t="inlineStr"><is><t xml:space="preserve">${_xml(value?.toString() ?? '')}</t></is></c>');
        }
      }
      sheet.write('</row>');
    }
    sheet.write('</sheetData></worksheet>');
    final files = <String, String>{
      '[Content_Types].xml': '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/></Types>',
      '_rels/.rels': '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>',
      'xl/workbook.xml': '<?xml version="1.0" encoding="UTF-8"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Customer Ledger" sheetId="1" r:id="rId1"/></sheets></workbook>',
      'xl/_rels/workbook.xml.rels': '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>',
      'xl/styles.xml': '<?xml version="1.0" encoding="UTF-8"?><styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts><fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills><borders count="1"><border/></borders><cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs><cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="4" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/></cellXfs><cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>',
      'xl/worksheets/sheet1.xml': sheet.toString(),
    };
    final archive = Archive();
    for (final entry in files.entries) {archive.addFile(ArchiveFile.string(entry.key, entry.value));}
    return ZipEncoder().encodeBytes(archive);
  }
}
