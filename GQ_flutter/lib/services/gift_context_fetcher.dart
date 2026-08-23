import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

/// Fetches a gift's product page URL and extracts useful context (title,
/// description) to enrich the AI's understanding of the gift. Mirrors the
/// Kotlin app's GiftContextFetcher — silently fails if the URL is
/// unreachable, since the game works fine without it.
class GiftContextFetcher {
  GiftContextFetcher._();

  static Future<String> fetch(String link) async {
    if (link.trim().isEmpty) return '';

    try {
      final uri = Uri.tryParse(link);
      if (uri == null) return '';

      final response = await http
          .get(uri, headers: {'User-Agent': 'Mozilla/5.0'})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return '';

      // Only look at the first 50KB — enough for meta tags, avoids huge pages.
      final html = response.body.length > 50000
          ? response.body.substring(0, 50000)
          : response.body;

      final pageTitle = _extractMeta(html, 'og:title', property: true)
          .ifBlank(() => _extractTag(html, 'title'));
      final pageDesc = _extractMeta(html, 'og:description', property: true)
          .ifBlank(() => _extractMeta(html, 'description', property: false));

      if (pageTitle.isEmpty && pageDesc.isEmpty) return '';

      final buffer = StringBuffer()
        ..writeln()
        ..writeln('ADDITIONAL GIFT CONTEXT FROM PRODUCT PAGE:');
      if (pageTitle.isNotEmpty) buffer.writeln('- Product: $pageTitle');
      if (pageDesc.isNotEmpty) {
        final trimmed =
            pageDesc.length > 200 ? pageDesc.substring(0, 200) : pageDesc;
        buffer.writeln('- Description: $trimmed');
      }
      return buffer.toString();
    } catch (e) {
      developer.log('Could not fetch gift URL: $e', name: 'GiftQuest');
      return '';
    }
  }

  static String _extractMeta(String html, String key, {required bool property}) {
    final attr = property ? 'property' : 'name';
    final pattern1 = RegExp(
      'meta[^>]+$attr="$key"[^>]+content="([^"]+)"',
      caseSensitive: false,
    );
    final pattern2 = RegExp(
      'meta[^>]+content="([^"]+)"[^>]+$attr="$key"',
      caseSensitive: false,
    );
    return (pattern1.firstMatch(html) ?? pattern2.firstMatch(html))
            ?.group(1)
            ?.trim() ??
        '';
  }

  static String _extractTag(String html, String tag) {
    final pattern = RegExp('<$tag[^>]*>(.*?)</$tag>', caseSensitive: false);
    return pattern.firstMatch(html)?.group(1)?.trim() ?? '';
  }
}

extension _IfBlank on String {
  String ifBlank(String Function() fallback) => isEmpty ? fallback() : this;
}
