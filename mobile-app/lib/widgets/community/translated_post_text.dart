import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/community_translation_preferences_service.dart';
import '../../core/services/community_translation_service.dart';
import '../../core/services/locale_service.dart';
import '../../utils/language_labels.dart';

class TranslatedPostText extends ConsumerStatefulWidget {
  final String originalText;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final Color? annotationColor;
  final Color? actionColor;
  final Color? settingsIconColor;
  final bool showTranslationSettings;

  const TranslatedPostText({
    super.key,
    required this.originalText,
    this.style,
    this.maxLines,
    this.overflow,
    this.annotationColor,
    this.actionColor,
    this.settingsIconColor,
    this.showTranslationSettings = true,
  });

  @override
  ConsumerState<TranslatedPostText> createState() => _TranslatedPostTextState();
}

class _TranslatedPostTextState extends ConsumerState<TranslatedPostText> {
  String? _translatedText;
  String? _sourceLanguageCode;
  bool _isLoading = false;
  bool _showOriginal = false;
  String _lastTargetLanguageCode = '';

  @override
  void initState() {
    super.initState();
    _lastTargetLanguageCode =
        _normalizeLanguageCode(ref.read(localeProvider).languageCode);
    _translate();
  }

  @override
  void didUpdateWidget(covariant TranslatedPostText oldWidget) {
    super.didUpdateWidget(oldWidget);

    final localeCode =
        _normalizeLanguageCode(ref.read(localeProvider).languageCode);
    if (oldWidget.originalText != widget.originalText) {
      _showOriginal = false;
      _lastTargetLanguageCode = localeCode;
      _translate();
      return;
    }

    if (localeCode != _lastTargetLanguageCode) {
      _showOriginal = false;
      _lastTargetLanguageCode = localeCode;
      _translate();
    }
  }

  Future<void> _translate() async {
    final text = widget.originalText.trim();
    if (text.isEmpty) {
      setState(() {
        _translatedText = widget.originalText;
        _sourceLanguageCode = null;
        _isLoading = false;
      });
      return;
    }

    final targetLanguageCode =
        _normalizeLanguageCode(ref.read(localeProvider).languageCode);

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await CommunityTranslationService.translate(
        text: widget.originalText,
        targetLanguageCode: targetLanguageCode,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _translatedText = result.translatedText;
        _sourceLanguageCode = result.sourceLanguageCode;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _translatedText = widget.originalText;
        _sourceLanguageCode = null;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final watchedLocaleCode =
        _normalizeLanguageCode(ref.watch(localeProvider).languageCode);
    final autoTranslateDisabledSources =
        ref.watch(communityTranslationPreferencesProvider);
    if (watchedLocaleCode != _lastTargetLanguageCode) {
      _lastTargetLanguageCode = watchedLocaleCode;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _showOriginal = false;
        _translate();
      });
    }

    final hasTranslation = !_isLoading &&
        _translatedText != null &&
        _translatedText != widget.originalText;
    final normalizedSourceLanguageCode = _sourceLanguageCode == null
        ? null
        : normalizeCommunityTranslationLanguageCode(_sourceLanguageCode!);
    final autoTranslateEnabled = normalizedSourceLanguageCode == null
        ? true
        : !autoTranslateDisabledSources.contains(normalizedSourceLanguageCode);
    final showingTranslated = hasTranslation
        ? (autoTranslateEnabled ? !_showOriginal : _showOriginal)
        : false;
    final textToShow = showingTranslated
        ? (_translatedText ?? widget.originalText)
        : widget.originalText;
    final languageLabel = _sourceLanguageCode == null
        ? 'original language'
        : _languageName(_sourceLanguageCode!);
    final bannerText = showingTranslated
        ? 'Translated from $languageLabel'
        : autoTranslateEnabled
            ? 'Showing original'
            : 'Translation available from $languageLabel';
    final annotationColor = widget.annotationColor ?? Colors.grey[700]!;
    final actionColor =
        widget.actionColor ?? Theme.of(context).colorScheme.primary;
    final settingsIconColor = widget.settingsIconColor ?? Colors.grey[700]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (hasTranslation) ...<Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.g_translate_rounded,
                size: 16,
                color: annotationColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: <Widget>[
                    if (showingTranslated)
                      Text(
                        bannerText,
                        style: TextStyle(
                          fontSize: 12,
                          color: annotationColor,
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    else
                      Text(
                        bannerText,
                        style: TextStyle(
                          fontSize: 12,
                          color: annotationColor,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _showOriginal = !_showOriginal;
                        });
                      },
                      child: Text(
                        showingTranslated
                            ? 'Show original'
                            : 'Show translation',
                        style: TextStyle(
                          fontSize: 12,
                          color: actionColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.showTranslationSettings)
                IconButton(
                  onPressed: normalizedSourceLanguageCode == null
                      ? null
                      : () => _showTranslationOptionsSheet(
                            context,
                            sourceLanguageCode: normalizedSourceLanguageCode,
                            sourceLanguageLabel: languageLabel,
                            autoTranslateEnabled: autoTranslateEnabled,
                          ),
                  icon: const Icon(Icons.settings, size: 18),
                  splashRadius: 18,
                  color: settingsIconColor,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
          const SizedBox(height: 4),
        ],
        Text(
          textToShow,
          style: widget.style,
          maxLines: widget.maxLines,
          overflow: widget.overflow,
        ),
      ],
    );
  }

  String _normalizeLanguageCode(String code) {
    final normalized = code.trim().toLowerCase();
    if (normalized == 'zh') {
      return 'zh-CN';
    }
    return normalized;
  }

  String _languageName(String code) {
    final (name, _) = languageNameAndCode(code);
    return name ?? code.toUpperCase();
  }

  Future<void> _showTranslationOptionsSheet(
    BuildContext context, {
    required String sourceLanguageCode,
    required String sourceLanguageLabel,
    required bool autoTranslateEnabled,
  }) async {
    var localAutoTranslateEnabled = autoTranslateEnabled;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Automatic Translation',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Google Translate will automatically translate posts written in $sourceLanguageLabel to your current app language. You can turn this off for this language at any time.',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.45,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SwitchListTile.adaptive(
                    value: localAutoTranslateEnabled,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Automatically translate $sourceLanguageLabel',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Changes apply to currently loaded and newly loaded community posts.',
                    ),
                    onChanged: (value) async {
                      setSheetState(() {
                        localAutoTranslateEnabled = value;
                      });
                      await ref
                          .read(
                              communityTranslationPreferencesProvider.notifier)
                          .setAutoTranslateEnabled(sourceLanguageCode, value);
                      if (!mounted) {
                        return;
                      }
                      setState(() {
                        _showOriginal = false;
                      });
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
