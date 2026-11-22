import 'package:flutter/material.dart';

const List<String> kNotionFolderIcons = [
  '📁', '📚', '💻', '🔬', '📐', '📝',
  '🎨', '💡', '⚡', '🚀', '🧠', '🏛️',
  '📖', '🧪', '📊', '🎯', '🌐', '🔢',
  '🌿', '⚙️', '🖋️', '🪐', '🎬', '🧩',
];

/// Shows a drawer to create a new folder with a Notion-style icon.
/// Returns a Record `({String name, String icon})?` or null if cancelled.
Future<({String name, String icon})?> showCreateFolderSheet(BuildContext context) {
  return showModalBottomSheet<({String name, String icon})>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => const _FolderSheet(),
  );
}

/// Shows a drawer to rename or change icon for an existing folder.
Future<({String name, String icon})?> showEditFolderSheet(
  BuildContext context, {
  required String initialName,
  required String initialIcon,
}) {
  return showModalBottomSheet<({String name, String icon})>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _FolderSheet(
      initialName: initialName,
      initialIcon: initialIcon,
      isEditing: true,
    ),
  );
}

class _FolderSheet extends StatefulWidget {
  final String? initialName;
  final String? initialIcon;
  final bool isEditing;

  const _FolderSheet({
    this.initialName,
    this.initialIcon,
    this.isEditing = false,
  });

  @override
  State<_FolderSheet> createState() => _FolderSheetState();
}

class _FolderSheetState extends State<_FolderSheet> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();
  late String _selectedIcon;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName ?? '');
    _selectedIcon = widget.initialIcon ?? '📁';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop((
        name: _controller.text.trim(),
        icon: _selectedIcon,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: colors.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            widget.isEditing ? 'Edit Folder' : 'New Folder',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),

          // Notion-style Large Icon Display & Prompt
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Center(
                child: Text(
                  _selectedIcon,
                  style: const TextStyle(fontSize: 32),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select an icon',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),

          // Icon Picker Horizontal Grid / Scroll
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: kNotionFolderIcons.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final icon = kNotionFolderIcons[index];
                final isSelected = icon == _selectedIcon;
                return InkWell(
                  onTap: () => setState(() => _selectedIcon = icon),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colors.primaryContainer
                          : colors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? colors.primary
                            : colors.outlineVariant.withValues(alpha: 0.3),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(icon, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),

          // Name form
          Form(
            key: _formKey,
            child: TextFormField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Folder Name',
                hintText: 'e.g. Physics 101, Computer Science',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a folder name';
                }
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(height: 20),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(widget.isEditing ? 'Save' : 'Create Folder'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
