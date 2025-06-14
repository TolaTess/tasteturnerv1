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
          style: TextStyle(
            height: 1.5,
            color: isDarkMode ? kWhite : kBlack,  
            fontSize: getPercentageWidth(4, context),
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SafeTextField(
                controller: titleController,
                style: TextStyle(
                  color: isDarkMode ? kWhite : kBlack,
                ),
                decoration: InputDecoration(
                  labelText: 'Title',
                  labelStyle: TextStyle(
                    height: 1.5,
                    color: isDarkMode ? kWhite : kBlack,
                  ),
                  enabledBorder: outlineInputBorder(20),
                  focusedBorder: outlineInputBorder(20),
                ),
              ),
              SafeTextField(
                controller: valueController,
                style: TextStyle(
                  color: isDarkMode ? kWhite : kBlack,
                ),
                decoration: InputDecoration(
                  labelText: 'Value',
                  labelStyle: TextStyle(
                    height: 1.5,
                    color: isDarkMode ? kWhite : kBlack,
                  ),
                  hintStyle: TextStyle(
                    height: 1.5,
                    color: isDarkMode ? kWhite : kBlack,
                  ),
                  enabledBorder: outlineInputBorder(20),
                  focusedBorder: outlineInputBorder(20),
                ),
              ),
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
                            style: TextStyle(
                              height: 1.5,
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
              style: TextStyle(
                height: 1.5,
                color: getThemeProvider(context).isDarkMode ? kWhite : kBlack,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              if (titleController.text.isEmpty ||
                  valueController.text.isEmpty) {
                return;
              }

              final newItem = RoutineItem(
                id: titleController.text,
                title: titleController.text,
                value: valueController.text,
                type: selectedType,
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
              style: const TextStyle(
                height: 1.5,
                color: kAccent,
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
                style: TextStyle(
                  fontSize: getPercentageWidth(3.5, context),
                ),
              ),
              children: [
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    bool isEnabled = item.title == 'Water Intake' ||
                        item.title == 'Nutrition Goal' ||
                        item.title == 'Steps';
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
                            item.title,
                            style: TextStyle(
                              color: isDarkMode ? kWhite : kBlack,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            item.value,
                            style: const TextStyle(
                              color: kLightGrey,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isEnabled)
                                IconButton(
                                  icon: Icon(Icons.edit,
                                      color: isDarkMode ? kWhite : kBlack),
                                  onPressed: () =>
                                      _showEditDialog(item, isDarkMode),
                                ),
                              IconButton(
                                icon: Icon(
                                  item.isEnabled
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: item.isEnabled ? kAccent : kLightGrey,
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
                    icon: const Icon(Icons.add),
                    label: const Text('Add New Item'),
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
