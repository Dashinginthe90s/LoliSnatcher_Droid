import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:lolisnatcher/src/handlers/search_handler.dart';
import 'package:lolisnatcher/src/handlers/settings_handler.dart';
import 'package:lolisnatcher/src/widgets/common/pulse_widget.dart';
import 'package:lolisnatcher/src/widgets/common/settings_widgets.dart';

class PageNumberDialog extends StatefulWidget {
  const PageNumberDialog({super.key});

  @override
  State<PageNumberDialog> createState() => _PageNumberDialogState();
}

class _PageNumberDialogState extends State<PageNumberDialog> {
  final SearchHandler searchHandler = SearchHandler.instance;
  final SettingsHandler settingsHandler = SettingsHandler.instance;

  final TextEditingController pageNumberController = TextEditingController();
  final TextEditingController delayController = TextEditingController();

  @override
  void dispose() {
    pageNumberController.dispose();
    delayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    pageNumberController.text = searchHandler.currentBooruHandler.pageNum.toString();
    delayController.text = 200.toString();

    final int total = searchHandler.currentBooruHandler.totalCount.value;
    final int possibleMaxPageNum = total != 0 ? (total / settingsHandler.limit).round() : 0;

    return SettingsBottomSheet(
      title: const Text(
        'Page changer',
        style: TextStyle(fontSize: 20),
      ),
      contentItems: [
        SettingsTextInput(
          title: 'Page #',
          hintText: 'Page #',
          onlyInput: true,
          controller: pageNumberController,
          autofocus: true,
          inputType: TextInputType.number,
          numberButtons: true,
          numberStep: 1,
          numberMin: -1,
          numberMax: double.infinity,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a number';
            } else if (int.tryParse(value) == null) {
              return 'Please enter a valid number';
            }
            return null;
          },
        ),
        SettingsTextInput(
          title: 'Delay between loadings (ms)',
          hintText: 'Delay in ms',
          onlyInput: true,
          controller: delayController,
          autofocus: false,
          inputType: TextInputType.number,
          numberButtons: true,
          numberStep: 100,
          numberMin: 0,
          numberMax: 10000,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a number';
            } else if (int.tryParse(value) == null) {
              return 'Please enter a valid number';
            }
            return null;
          },
        ),
        SettingsButton(
          name: 'Current page #${searchHandler.pageNum.value}',
          action: () {
            pageNumberController.text = searchHandler.pageNum.value.toString();
          },
          drawTopBorder: true,
        ),
        if (possibleMaxPageNum != 0)
          SettingsButton(
            name: 'Possible max page #~$possibleMaxPageNum',
            action: () {
              pageNumberController.text = possibleMaxPageNum.toString();
            },
          ),
        Obx(
          () => searchHandler.isRunningAutoSearch.value
              ? const SettingsButton(
                  name: 'Search currently running!',
                  icon: PulseWidget(
                    child: Icon(
                      Icons.warning_amber,
                      color: Colors.yellow,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
      actionButtons: [
        ElevatedButton(
          child: const Text('Jump to page'),
          onPressed: () {
            if (pageNumberController.text.isNotEmpty) {
              searchHandler.changeCurrentTabPageNumber((int.tryParse(pageNumberController.text) ?? 0) - 1);
              Navigator.of(context).pop();
            }
          },
        ),
        const SizedBox(width: 10),
        Obx(
          () => ElevatedButton(
            onPressed: searchHandler.isRunningAutoSearch.value
                ? null
                : () {
                    if (pageNumberController.text.isNotEmpty) {
                      searchHandler.searchCurrentTabUntilPageNumber(
                        (int.tryParse(pageNumberController.text) ?? 0) - 1,
                        customDelay: int.tryParse(delayController.text) ?? 200,
                      );
                      Navigator.of(context).pop();
                    }
                  },
            child: const Text('Search until page'),
          ),
        ),
        Obx(
          () => searchHandler.isRunningAutoSearch.value
              ? Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: ElevatedButton(
                    onPressed: () {
                      searchHandler.isRunningAutoSearch.value = false;
                    },
                    child: const Text('Stop search'),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
