import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

class SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onSearch;
  final VoidCallback onClear;

  const SearchBar({
    super.key,
    required this.controller,
    required this.onSearch,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(25),
      ),
      child: Builder(builder: (context) {
        final l10n = AppLocalizations.of(context);
        return TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: l10n.searchHint,
            hintStyle: TextStyle(
              color: Colors.grey[500],
              fontSize: 16,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: Colors.grey[500],
            ),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear,
                      color: Colors.grey[500],
                    ),
                    onPressed: onClear,
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 15,
            ),
          ),
          onSubmitted: onSearch,
          onChanged: (value) {
            // Trigger rebuild to show/hide clear button
            (context as Element).markNeedsBuild();
          },
          textInputAction: TextInputAction.search,
        );
      }),
    );
  }
}
