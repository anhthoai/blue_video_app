import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:charset/charset.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class TxtToEpubConverter {
  static String readFileWithEncoding(Uint8List bytes) {
    bool checkGarbled(String content) {
      final garbledPattern = RegExp(
          r'Õ|Ê||Ç|³|¾|Ð|Ó|Î|Á|É||Ã|Ä|Å|Æ|Ë|Ì|Í|Ï|Ò|Ó|Ô|Õ|Ö|Ù|Ú|Û|Ü|Ý|à|á|â|ã|ä|å|æ|è|é|ê|ë|ì|í|î|ï|ð|ñ|ò|ó|ô|õ|ö|ù|ú|û|ü|ý|ÿ|\x00-\x1F\x7F|｡｢｣､･ｦｧｨｩｪｫｬｭｮｯｰｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ|€|');
      final sampleContent =
          content.length > 500 ? content.substring(0, 500) : content;

      final matches = garbledPattern.allMatches(sampleContent);
      final garbledCount = matches.length;

      return garbledCount / sampleContent.length > 20 / 500;
    }

    final decoder = {
      'utf8': utf8.decode,
      'gbk': gbk.decode,
      'latin1': latin1.decode,
      'utf16': utf16.decode,
      'utf32': utf32.decode,
    };

    for (final entry in decoder.entries) {
      try {
        final content = entry.value(bytes);
        if (!checkGarbled(content)) {
          return content;
        }
      } catch (e) {
        // Try next encoding
      }
    }

    // Fallback to UTF-8
    return utf8.decode(bytes, allowMalformed: true);
  }

  static String _normalizeLineBreaks(String input) {
    return input.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  }

  static String _escapeXml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static List<_Section> _fallbackChunking(String filename, String content) {
    final sections = <_Section>[];
    if (content.length <= 20000) {
      sections.add(_Section(filename, content.trim(), 2));
      return sections;
    }

    var startIndex = 0;
    while (startIndex < content.length) {
      final endIndex = startIndex + 20000;
      if (endIndex >= content.length) {
        sections.add(_Section('No.${sections.length + 1}',
            content.substring(startIndex).trim(), 2));
        break;
      }

      final nextNewline = content.indexOf('\n', endIndex);
      final chapterEndIndex = nextNewline == -1 ? content.length : nextNewline;

      sections.add(_Section('No.${sections.length + 1}',
          content.substring(startIndex, chapterEndIndex).trim(), 2));
      startIndex = chapterEndIndex + 1;
    }

    return sections;
  }

  static Future<Uint8List> convertTxtToEpub({
    required Uint8List txtBytes,
    required String filename,
  }) async {
    // Read and decode text
    String content = readFileWithEncoding(txtBytes);
    content = _normalizeLineBreaks(content);

    // Extract title from filename
    var titleString = filename;
    if (titleString.contains('.')) {
      titleString = titleString.split('.').sublist(0, titleString.split('.').length - 1).join('.');
    }
    final titleMatch = RegExp(r'(?<=《)[^》]+').firstMatch(titleString);
    final title = titleMatch?.group(0) ?? titleString;
    final author = RegExp(r'(?<=作者：).*').firstMatch(titleString)?.group(0) ?? 'Unknown';

    // Split into sections (simplified - just chunk if large)
    final sections = _fallbackChunking(title, content);

    // Create temporary directory for EPUB structure
    final tempDir = await getTemporaryDirectory();
    final epubDir = Directory('${tempDir.path}/epub_${DateTime.now().millisecondsSinceEpoch}');
    if (epubDir.existsSync()) {
      epubDir.deleteSync(recursive: true);
    }
    epubDir.createSync(recursive: true);

    // mimetype (must be first, uncompressed)
    final mimetypeFile = File('${epubDir.path}/mimetype');
    mimetypeFile.createSync();
    mimetypeFile.writeAsStringSync('application/epub+zip');

    // META-INF/container.xml
    final metainfDir = Directory('${epubDir.path}/META-INF');
    metainfDir.createSync();
    final containerFile = File('${epubDir.path}/META-INF/container.xml');
    containerFile.createSync();
    containerFile.writeAsStringSync('''<?xml version="1.0" encoding="utf-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''');

    // content.opf
    final manifestItems = List.generate(
        sections.length,
        (index) =>
            '    <item id="item$index" href="xhtml/$index.xhtml" media-type="application/xhtml+xml"/>')
        .join('\n');
    final spineItems = List.generate(
        sections.length, (index) => '    <itemref idref="item$index"/>')
        .join('\n');

    // OEBPS
    final oebpsDir = Directory('${epubDir.path}/OEBPS');
    oebpsDir.createSync();

    // content.opf
    final contentFile = File('${oebpsDir.path}/content.opf');
    contentFile.createSync();
    contentFile.writeAsStringSync('''<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="pub-id">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>${_escapeXml(title)}</dc:title>
    <dc:creator>${_escapeXml(author)}</dc:creator>
    <dc:identifier id="pub-id">urn:uuid:${const Uuid().v4()}</dc:identifier>
  </metadata>

  <manifest>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="css" href="style.css" media-type="text/css"/>
    $manifestItems
  </manifest>

  <spine toc="ncx">
    $spineItems
  </spine>
</package>''');

    // toc.ncx
    final tocItems = List.generate(sections.length, (index) {
      final section = sections[index];
      final sectionTitle = section.title.trim().isNotEmpty
          ? section.title.trim()
          : 'Section ${index + 1}';
      return '''    <navPoint id="navPoint-$index" playOrder="${index + 1}">
      <navLabel><text>${_escapeXml(sectionTitle)}</text></navLabel>
      <content src="xhtml/$index.xhtml"/>
    </navPoint>''';
    }).join('\n');

    // toc.ncx
    final tocFile = File('${oebpsDir.path}/toc.ncx');
    tocFile.createSync();
    tocFile.writeAsStringSync('''<?xml version="1.0" encoding="utf-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1" xml:lang="en">
  <head>
    <meta name="dtb:uid" content="urn:uuid:${const Uuid().v4()}"/>
    <meta name="dtb:depth" content="1"/>
    <meta name="dtb:totalPageCount" content="${sections.length}"/>
  </head>
  <docTitle>
    <text>${_escapeXml(title)}</text>
  </docTitle>
  <navMap>
$tocItems
  </navMap>
</ncx>''');

    // style.css
    final styleFile = File('${oebpsDir.path}/style.css');
    styleFile.createSync();
    styleFile.writeAsStringSync('''body {

}
''');

    // xhtml
    final xhtmlDir = Directory('${oebpsDir.path}/xhtml');
    xhtmlDir.createSync();
    
    // xhtml files
    for (var i = 0; i < sections.length; i++) {
      final section = sections[i];
      final rawTitle = section.title.trim();
      final level = section.level.clamp(1, 6);
      final sectionContent = section.content;

      final heading = rawTitle.isEmpty
          ? ''
          : '    <h$level>${_escapeXml(rawTitle)}</h$level>';

      final paragraphLines = sectionContent
          .split('\n')
          .map((e) => e.trim())
          .where((line) => line.isNotEmpty)
          .map((line) => '    <p>${_escapeXml(line)}</p>')
          .toList();

      final bodyBuffer = StringBuffer();
      if (heading.isNotEmpty) {
        bodyBuffer.writeln(heading);
      }
      for (final line in paragraphLines) {
        bodyBuffer.writeln(line);
      }

      final bodyContent = bodyBuffer.toString().trimRight();

      final xhtml = '''<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
  <head>
    <title>${_escapeXml(rawTitle.isEmpty ? title : rawTitle)}</title>
  </head>
  <body>
${bodyContent.isEmpty ? '' : '$bodyContent\n'}
  </body>
</html>''';
      final xhtmlFile = File('${xhtmlDir.path}/$i.xhtml');
      xhtmlFile.createSync();
      xhtmlFile.writeAsStringSync(xhtml);
    }

    // Create ZIP (EPUB) - mimetype must be first and uncompressed
    final epubFile = File('${tempDir.path}/${title.replaceAll(RegExp(r'[^\w\s-]'), '_')}.epub');
    epubFile.createSync();
    
    final encoder = ZipFileEncoder();
    encoder.create(epubFile.path);
    
    // Add mimetype first (must be first entry, uncompressed per EPUB spec)
    await encoder.addFile(mimetypeFile);
    
    // Add rest compressed
    await encoder.addDirectory(metainfDir);
    await encoder.addDirectory(oebpsDir);
    
    await encoder.close();

    // Read the EPUB file
    final epubBytes = await epubFile.readAsBytes();
    
    // Cleanup
    epubDir.deleteSync(recursive: true);
    epubFile.deleteSync();
    
    return Uint8List.fromList(epubBytes);
  }
}

class _Section {
  _Section(this.title, this.content, this.level);

  final String title;
  final String content;
  final int level;
}

