import 'package:flutter/material.dart';
import 'package:tasteturner/pages/safe_text_field.dart';
import '../constants.dart';
import '../data_models/routine_item.dart';
import '../service/routine_service.dart';
import '../helper/utils.dart';

class DailyRoutineList extends StatefulWidget {
  final String userId;
  final bool isRoutineEdit;

  const DailyRoutineList(
      {Key? key, required this.userId, required this.isRoutineEdit})
      : super(key: key);

  @override
  State<DailyRoutineList> createState() => _DailyRoutineListState();
}

class _DailyRoutineListState extends State<DailyRoutineList> {
  late Future<List<RoutineItem>> _routineItems;
  final _routineService = RoutineService.instance;

  @override
  void initState() {
    super.initState();
    _routineItems = _routineService.getRoutineItems(userService.userId ?? '');
  }

  Future<void> _showEditDialog(RoutineItem? item, bool isDarkMode) async {
    final isNewItem = item == null;
    final titleController = TextEditingController(text: item?.title ?? '');
    final valueController = TextEditingController(text: item?.value ?? '');
    String selectedType = item?.type ?? 'duration';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        backgroundColor: isDarkMode ? kDarkGrey : kWhite,
        title: Text(
          isNewItem ? 'Add Routine Item' : 'Edit Routine Item',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: isDarkMode ? kWhite : kBlack,
              ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SafeTextField(
                controller: titleController,
                enabled: isNewItem, // Only allow editing title for new items
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: isNewItem
                          ? (isDarkMode ? kWhite : kBlack)
                          : kLightGrey, // Grey out when disabled
                    ),
                decoration: InputDecoration(
                  labelText: 'Title',
                  labelStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: isNewItem
                            ? (isDarkMode ? kWhite : kBlack)
                            : kLightGrey, // Grey out label when disabled
                      ),
                  enabledBorder: outlineInputBorder(20),
                  focusedBorder: outlineInputBorder(20),
                  disabledBorder: outlineInputBorder(20).copyWith(
                    borderSide: BorderSide(color: kLightGrey.withOpacity(0.5)),
                  ),
                  fillColor: isNewItem
                      ? (isDarkMode ? kDarkGrey : kWhite)
                      : (isDarkMode
                          ? Colors.grey[800]
                          : Colors
                              .grey[200]), // Different background when disabled
                  filled: true,
                ),
              ),
              const SizedBox(height: 16),
              SafeTextField(
                controller: valueController,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: isDarkMode ? kWhite : kBlack,
                    ),
                decoration: InputDecoration(
                  labelText: 'Value',
                  labelStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: isDarkMode ? kWhite : kBlack,
                      ),
                  hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: isDarkMode ? kWhite : kBlack,
                      ),
                  enabledBorder: outlineInputBorder(20),
                  focusedBorder: outlineInputBorder(20),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDarkMode ? kDarkGrey : kWhite,
                  contentPadding: const EdgeInsets.all(8),
                  enabledBorder: outlineInputBorder(20),
                  focusedBorder: outlineInputBorder(20),
                ),
                items: ['time', 'duration', 'quantity']
                    .map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(
                            type.toUpperCase(),
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: isDarkMode ? kWhite : kBlack,
                                    ),
                          ),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    selectedType = value;
                  }
                },
                dropdownColor: kAccent,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color:
                        getThemeProvider(context).isDarkMode ? kWhite : kBlack,
                  ),
            ),
          ),
          TextButton(
            onPressed: () async {
              // For new items, check both title and value
              // For existing items, only check value since title can't be changed
              if ((isNewItem && titleController.text.isEmpty) ||
                  valueController.text.isEmpty) {
                return;
              }

              final newItem = RoutineItem(
                id: item?.id ?? titleController.text,
                title: titleController.text,
                value: valueController.text,
                type: selectedType,
                isEnabled: item?.isEnabled ?? true,
                isCompleted: item?.isCompleted ?? false,
              );

              if (isNewItem) {
                await _routineService.addRoutineItem(widget.userId, newItem);
              } else {
                await _routineService.updateRoutineItem(widget.userId, newItem);
              }

              setState(() {
                _routineItems = _routineService.getRoutineItems(widget.userId);
              });

              if (mounted) Navigator.pop(context);
            },
            child: Text(
              isNewItem ? 'Add' : 'Save',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: kAccent,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteDialog(RoutineItem item, bool isDarkMode) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        backgroundColor: isDarkMode ? kDarkGrey : kWhite,
        title: Text(
          'Delete Routine Item',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: isDarkMode ? kWhite : kBlack,
              ),
        ),
        content: Text(
          'Are you sure you want to delete "${item.title}"? This action cannot be undone.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: isDarkMode ? kWhite : kBlack,
              ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: isDarkMode ? kWhite : kBlack,
                  ),
            ),
          ),
          TextButton(
            onPressed: () async {
              await _routineService.deleteRoutineItem(widget.userId, item);
              setState(() {
                _routineItems = _routineService.getRoutineItems(widget.userId);
              });
              if (mounted) Navigator.pop(context);
            },
            child: Text(
              'Delete',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: kRed,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = getThemeProvider(context).isDarkMode;

    return FutureBuilder<List<RoutineItem>>(
      future: _routineItems,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: kAccent));
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final items = snapshot.data ?? [];

        return Column(
          children: [
            ExpansionTile(
              collapsedIconColor: kAccent,
              iconColor: kAccent,
              textColor: kAccent,
              collapsedTextColor: isDarkMode ? kWhite : kDarkGrey,
              initiallyExpanded: widget.isRoutineEdit,
              title: Text(
                'Routine Items',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: kAccent,
                    ),
              ),
              children: [
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    // Check if this is an essential item that cannot be deleted
                    bool isEssential = item.title == 'Water Intake' ||
                        item.title == 'Nutrition Goal' ||
                        item.title == 'Steps' ||
                        item.title == 'Water';
                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      margin: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 4),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDarkMode ? kDarkGrey : kWhite,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListTile(
                          title: Text(
                            item.title == 'Water Intake'
                                ? 'Water'
                                : item.title == 'Nutrition Goal'
                                    ? 'Meals'
                                    : capitalizeFirstLetter(item.title),
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: isDarkMode ? kWhite : kBlack,
                                      fontWeight: FontWeight.w500,
                                    ),
                          ),
                          subtitle: Text(
                            item.value,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: kLightGrey,
                                ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Edit button - show for all non-essential items
                              if (!isEssential)
                                IconButton(
                                  icon: Icon(Icons.edit,
                                      color: isDarkMode ? kWhite : kBlack,
                                      size: getIconScale(7, context)),
                                  onPressed: () =>
                                      _showEditDialog(item, isDarkMode),
                                ),
                              // Delete button - show for all non-essential items
                              if (!isEssential)
                                IconButton(
                                  icon: Icon(Icons.delete,
                                      color: kRed,
                                      size: getIconScale(7, context)),
                                  onPressed: () =>
                                      _showDeleteDialog(item, isDarkMode),
                                ),
                              // Visibility toggle button
                              IconButton(
                                icon: Icon(
                                  item.isEnabled
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: item.isEnabled ? kAccent : kLightGrey,
                                  size: getIconScale(7, context),
                                ),
                                onPressed: () async {
                                  int totalItems = items.length;
                                  int disabledCount = items
                                      .where((item) => !item.isEnabled)
                                      .length;

                                  // If this enabled item is being disabled and it's the last one
                                  if (item.isEnabled &&
                                      disabledCount == totalItems - 1) {
                                    // If we're disabling the last enabled item
                                    await _routineService.setAllDisabled(true);
                                  } else if (!item.isEnabled &&
                                      disabledCount == totalItems) {
                                    // If we're enabling the first item when all were disabled
                                    await _routineService.setAllDisabled(false);
                                  }

                                  await _routineService.toggleRoutineItem(
                                    widget.userId,
                                    item,
                                  );
                                  setState(() {
                                    _routineItems = _routineService
                                        .getRoutineItems(widget.userId);
                                  });
                                },
                              ),
                            ],
                          ),
                          tileColor: item.isEnabled
                              ? null
                              : (isDarkMode
                                  ? Colors.grey[900]
                                  : Colors.grey[200]),
                        ),
                      ),
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton.icon(
                    onPressed: () => _showEditDialog(null, isDarkMode),
                    icon: Icon(Icons.add, size: getIconScale(7, context)),
                    label: Text(
                      'Add New Item',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: kWhite,
                          ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccent,
                      foregroundColor: kWhite,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
