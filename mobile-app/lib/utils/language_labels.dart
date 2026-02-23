import 'package:media_kit/media_kit.dart';

String trackId(Object? id) => id == null ? '' : '$id';

// ISO language names for common 639-1 and 639-2/3 codes.
// Used to turn embedded track language tags into user-friendly labels.
const Map<String, String> _isoLangName = {
	// ISO 639-1
	'aa': 'Afar',
	'ab': 'Abkhaz',
	'af': 'Afrikaans',
	'am': 'Amharic',
	'ar': 'Arabic',
	'as': 'Assamese',
	'az': 'Azerbaijani',
	'be': 'Belarusian',
	'bg': 'Bulgarian',
	'bn': 'Bengali',
	'bo': 'Tibetan',
	'br': 'Breton',
	'bs': 'Bosnian',
	'ca': 'Catalan',
	'cs': 'Czech',
	'cy': 'Welsh',
	'da': 'Danish',
	'de': 'German',
	'el': 'Greek',
	'en': 'English',
	'eo': 'Esperanto',
	'es': 'Spanish',
	'et': 'Estonian',
	'eu': 'Basque',
	'fa': 'Persian',
	'fi': 'Finnish',
	'fr': 'French',
	'ga': 'Irish',
	'gl': 'Galician',
	'gu': 'Gujarati',
	'he': 'Hebrew',
	'hi': 'Hindi',
	'hr': 'Croatian',
	'hu': 'Hungarian',
	'hy': 'Armenian',
	'id': 'Indonesian',
	'is': 'Icelandic',
	'it': 'Italian',
	'ja': 'Japanese',
	'jv': 'Javanese',
	'ka': 'Georgian',
	'kk': 'Kazakh',
	'km': 'Khmer',
	'kn': 'Kannada',
	'ko': 'Korean',
	'ku': 'Kurdish',
	'ky': 'Kyrgyz',
	'la': 'Latin',
	'lo': 'Lao',
	'lt': 'Lithuanian',
	'lv': 'Latvian',
	'mk': 'Macedonian',
	'ml': 'Malayalam',
	'mn': 'Mongolian',
	'mr': 'Marathi',
	'ms': 'Malay',
	'my': 'Burmese',
	'ne': 'Nepali',
	'nl': 'Dutch',
	'no': 'Norwegian',
	'pa': 'Punjabi',
	'pl': 'Polish',
	'pt': 'Portuguese',
	'ro': 'Romanian',
	'ru': 'Russian',
	'si': 'Sinhala',
	'sk': 'Slovak',
	'sl': 'Slovenian',
	'sq': 'Albanian',
	'sr': 'Serbian',
	'sv': 'Swedish',
	'sw': 'Swahili',
	'ta': 'Tamil',
	'te': 'Telugu',
	'th': 'Thai',
	'tl': 'Tagalog',
	'tr': 'Turkish',
	'uk': 'Ukrainian',
	'ur': 'Urdu',
	'uz': 'Uzbek',
	'vi': 'Vietnamese',
	'zh': 'Chinese',

	// Common ISO 639-2/3 codes used by muxers.
	'ara': 'Arabic',
	'bul': 'Bulgarian',
	'ces': 'Czech',
	'cze': 'Czech',
	'dan': 'Danish',
	'deu': 'German',
	'ger': 'German',
	'ell': 'Greek',
	'gre': 'Greek',
	'eng': 'English',
	'spa': 'Spanish',
	'fra': 'French',
	'fre': 'French',
	'heb': 'Hebrew',
	'hin': 'Hindi',
	'hrv': 'Croatian',
	'hun': 'Hungarian',
	'hye': 'Armenian',
	'arm': 'Armenian',
	'ind': 'Indonesian',
	'ita': 'Italian',
	'jpn': 'Japanese',
	'kor': 'Korean',
	'nld': 'Dutch',
	'dut': 'Dutch',
	'nor': 'Norwegian',
	'pol': 'Polish',
	'por': 'Portuguese',
	'ron': 'Romanian',
	'rum': 'Romanian',
	'rus': 'Russian',
	'slk': 'Slovak',
	'slo': 'Slovak',
	'slv': 'Slovenian',
	'srp': 'Serbian',
	'swe': 'Swedish',
	'tha': 'Thai',
	'tur': 'Turkish',
	'ukr': 'Ukrainian',
	'urd': 'Urdu',
	'vie': 'Vietnamese',
	'zho': 'Chinese',
	'chi': 'Chinese',
	'cmn': 'Chinese (Mandarin)',
	'yue': 'Chinese (Cantonese)',
	'und': 'Unknown',
};

(String? name, String? code) languageNameAndCode(String? raw) {
	if (raw == null) return (null, null);
	final cleaned = raw.trim();
	if (cleaned.isEmpty) return (null, null);

	// Normalize separators and keep the primary code part.
	final normalized = cleaned.replaceAll('_', '-');
	final primary = normalized.split('-').first.trim().toLowerCase();
	if (primary.isEmpty) return (null, null);

	final name = _isoLangName[primary];
	return (name, normalized);
}

String formatLanguage(String? raw) {
	final (name, code) = languageNameAndCode(raw);
	if (name == null && code == null) return '';
	if (name != null && code != null) return '$name • $code';
	return name ?? code ?? '';
}

String _norm(String s) {
	return s
			.toLowerCase()
			.replaceAll(RegExp(r'[^a-z0-9]+'), '')
			.trim();
}

bool _isRedundantTitle({
	required String title,
	String? languageName,
	String? languageCode,
}) {
	final t = _norm(title);
	if (t.isEmpty) return true;

	final name = languageName == null ? '' : _norm(languageName);
	final code = languageCode == null ? '' : _norm(languageCode);
	final primary = languageCode == null
			? ''
			: _norm(languageCode.split('-').first);

	// Common cases where muxers put the language in the title.
	if (t == name && name.isNotEmpty) return true;
	if (t == code && code.isNotEmpty) return true;
	if (t == primary && primary.isNotEmpty) return true;
	if (t == 'und' || t == 'unknown') return true;

	return false;
}

String audioTrackLabel(AudioTrack t, {int? index}) {
	final id = trackId(t.id);
	if (id == trackId(AudioTrack.auto().id)) return 'Auto';
	if (id == trackId(AudioTrack.no().id)) return 'None';

	final title = (t.title ?? '').trim();
	final (name, code) = languageNameAndCode(t.language);
	final lang = formatLanguage(t.language);
	final parts = <String>[];
	if (title.isNotEmpty &&
			!_isRedundantTitle(title: title, languageName: name, languageCode: code)) {
		parts.add(title);
	}
	if (lang.isNotEmpty) parts.add(lang);
	if (parts.isEmpty && index != null) parts.add('Audio ${index + 1}');
	if (t.isDefault == true) parts.add('Default');
	return parts.join(' • ');
}

String subtitleTrackLabel(SubtitleTrack t, {int? index}) {
	final id = trackId(t.id);
	if (id == trackId(SubtitleTrack.auto().id)) return 'Auto';
	if (id == trackId(SubtitleTrack.no().id)) return 'None';

	final title = (t.title ?? '').trim();
	final (name, code) = languageNameAndCode(t.language);
	final lang = formatLanguage(t.language);
	final parts = <String>[];
	if (title.isNotEmpty &&
			!_isRedundantTitle(title: title, languageName: name, languageCode: code)) {
		parts.add(title);
	}
	if (lang.isNotEmpty) parts.add(lang);
	if (parts.isEmpty && index != null) parts.add('Subtitle ${index + 1}');
	if (t.isDefault == true) parts.add('Default');
	return parts.join(' • ');
}

