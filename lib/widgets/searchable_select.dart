import 'package:flutter/material.dart';

class SearchableSelect<T> extends StatelessWidget {
  const SearchableSelect({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.child,
  });

  final String label;
  final T? value;
  final Map<T?, String> options;
  final ValueChanged<T?>? onChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null && options.isNotEmpty;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        enabled: enabled,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: enabled
              ? () async {
                  final selection = await showDialog<({T? value})>(
                    context: context,
                    builder: (_) => _SelectDialog<T>(
                      label: label,
                      value: value,
                      options: options,
                    ),
                  );
                  if (context.mounted && selection != null) {
                    onChanged!(selection.value);
                  }
                }
              : null,
          child: child,
        ),
      ),
    );
  }
}

class SearchableSelectField<T> extends FormField<T> {
  SearchableSelectField({
    super.key,
    required String label,
    required T? value,
    required Map<T?, String> options,
    required ValueChanged<T?>? onChanged,
    InputDecoration decoration = const InputDecoration(),
    super.validator,
  }) : super(
         initialValue: value,
         enabled: onChanged != null && options.isNotEmpty,
         builder: (field) {
           final enabled = field.widget.enabled;
           final text = options[value];
           return SearchableSelect<T>(
             label: label,
             value: value,
             options: options,
             onChanged: enabled
                 ? (selection) {
                     field.didChange(selection);
                     onChanged!(selection);
                   }
                 : null,
             child: InputDecorator(
               isEmpty: text == null,
               decoration: decoration.copyWith(
                 enabled: enabled,
                 errorText: field.errorText,
                 suffixIcon: const Icon(Icons.arrow_drop_down),
               ),
               child: Text(
                 text ?? '',
                 maxLines: 1,
                 overflow: TextOverflow.ellipsis,
                 style: Theme.of(field.context).textTheme.bodyLarge?.copyWith(
                   color: enabled
                       ? null
                       : Theme.of(field.context).disabledColor,
                 ),
               ),
             ),
           );
         },
       );
}

class _SelectDialog<T> extends StatefulWidget {
  const _SelectDialog({
    required this.label,
    required this.value,
    required this.options,
  });

  final String label;
  final T? value;
  final Map<T?, String> options;

  @override
  State<_SelectDialog<T>> createState() => _SelectDialogState<T>();
}

class _SelectDialogState<T> extends State<_SelectDialog<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final words = _query.toLowerCase().trim().split(RegExp(r'\s+'));
    final matches = widget.options.entries.where((entry) {
      final label = entry.value.toLowerCase();
      return words.every(label.contains);
    }).toList();

    return AlertDialog(
      title: Text(widget.label),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search options',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (query) => setState(() => _query = query),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: matches.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('No matching options'),
                    )
                  : ListView.builder(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      shrinkWrap: true,
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final entry = matches[index];
                        final selected = entry.key == widget.value;
                        return ListTile(
                          title: Text(entry.value),
                          selected: selected,
                          trailing: selected ? const Icon(Icons.check) : null,
                          onTap: () =>
                              Navigator.of(context).pop((value: entry.key)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
