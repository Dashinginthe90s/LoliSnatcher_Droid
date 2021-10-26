import 'package:intl/intl.dart';

import 'package:LoliSnatcher/SettingsHandler.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'package:LoliSnatcher/SearchGlobals.dart';
import 'package:LoliSnatcher/ServiceHandler.dart';
import 'package:LoliSnatcher/libBooru/BooruItem.dart';
import 'package:LoliSnatcher/widgets/MarqueeText.dart';
import 'package:LoliSnatcher/Tools.dart';
import 'package:LoliSnatcher/widgets/FlashElements.dart';
import 'package:LoliSnatcher/widgets/SettingsWidgets.dart';

class TagView extends StatefulWidget {
  BooruItem booruItem;
  TagView(this.booruItem);
  @override
  _TagViewState createState() => _TagViewState();
}

class _TagViewState extends State<TagView> {
  final SettingsHandler settingsHandler = Get.find();
  final SearchHandler searchHandler = Get.find();
  List<List<String>> hatedAndLovedTags = [];
  ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    parseTags();
  }

  void parseTags() {
    hatedAndLovedTags = settingsHandler.parseTagsList(widget.booruItem.tagsList, isCapped: false);
    setState(() { });
  }

  Widget infoBuild() {
    final String fileName = Tools.getFileName(widget.booruItem.fileURL);
    final String fileRes = (widget.booruItem.fileWidth != null && widget.booruItem.fileHeight != null) ? '${widget.booruItem.fileWidth?.toInt() ?? ''}x${widget.booruItem.fileHeight?.toInt() ?? ''}' : '';
    final String fileSize = widget.booruItem.fileSize != null ? Tools.formatBytes(widget.booruItem.fileSize!, 2) : '';
    final String hasNotes = widget.booruItem.hasNotes != null ? widget.booruItem.hasNotes.toString() : '';
    final String itemId = widget.booruItem.serverId ?? '';
    final String rating = widget.booruItem.rating ?? '';
    final String score = widget.booruItem.score ?? '';
    final List<String> sources = widget.booruItem.sources ?? [];
    final bool tagsAvailable = widget.booruItem.tagsList.length > 0;
    String postDate = widget.booruItem.postDate ?? '';
    final String postDateFormat = widget.booruItem.postDateFormat ?? '';
    String formattedDate = '';
    if(postDate.isNotEmpty && postDateFormat.isNotEmpty) {
      try {
        // no timezone support in DateFormat? see: https://stackoverflow.com/questions/56189407/dart-parse-date-timezone-gives-unimplementederror/56190055
        // remove timezones from strings until they fix it
        DateTime parsedDate;
        if(postDateFormat == "unix"){
          parsedDate = DateTime.fromMillisecondsSinceEpoch(int.parse(postDate) * 1000);
        } else {
          postDate = postDate.replaceAll(RegExp(r'(?:\+|\-)\d{4}'), '');
          parsedDate = DateFormat(postDateFormat).parseLoose(postDate).toLocal();
        }
        // print(postDate);
        formattedDate = DateFormat('dd.MM.yyyy HH:mm').format(parsedDate);
      } catch(e) {
        print('$postDate $postDateFormat');
        print(e);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // infoText('Filename', fileName),
        infoText('ID', itemId),
        infoText('Rating', rating),
        infoText('Score', score),
        infoText('Resolution', fileRes),
        infoText('Size', fileSize),
        infoText('Has Notes', hasNotes, canCopy: false),
        infoText('Posted', formattedDate),
        sourcesList(sources),
        if(tagsAvailable) Divider(height: 4, thickness: 2, color: Colors.grey[800]),
        if(tagsAvailable) infoText('Tags', ' ', canCopy: false),
      ]
    );
  }

  Widget sourcesList(List<String> sources) {
    sources = sources.where((link) => link.trim().isNotEmpty).toList();
    if(sources.isNotEmpty) {
      return Container(
        child: Column(
          children: [
            Divider(height: 4, thickness: 2, color: Colors.grey[800]),
            infoText(sources.length == 1 ? 'Source' : 'Sources', ' ', canCopy: false),
            Column(children: 
              sources.map((link) => ListTile(
                onTap: () {
                  ServiceHandler.launchURL(link);
                },
                title: Text(link, overflow: TextOverflow.ellipsis)
              )).toList()
            )
          ],
        )
      );
    } else {
      return const SizedBox();
    }
  }

  Widget infoText(String title, String data, {bool canCopy = true}) {
    if(data.isNotEmpty) {
      return Container(
        child: ListTile(
          onTap: () {
            if(canCopy) {
              Clipboard.setData(ClipboardData(text: data));
              FlashElements.showSnackbar(
                context: context,
                duration: Duration(seconds: 2),
                title: Text(
                  "Copied $title to clipboard!",
                  style: TextStyle(fontSize: 20)
                ),
                content: Text(
                  data,
                  style: TextStyle(fontSize: 16)
                ),
                leadingIcon: Icons.copy,
                sideColor: Colors.green,
              );
            }
          },
          title: Row(
            children: [
              Text('$title: ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
              Expanded(child: Text(data, overflow: TextOverflow.ellipsis)),
            ]
          )
        )
      );
    } else {
      return const SizedBox();
    }
  }

  void tagDialog({
    required String tag,
    required bool isHated,
    required bool isLoved
  }) {
    Get.dialog(
      SettingsDialog(
        contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        contentItems: [
          Container(
            height: 60,
            width: Get.mediaQuery.size.width,
            child: ListTile(
              title: MarqueeText(
                text: tag,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                startPadding: 0,
                isExpanded: false,
              )
            )
          ),
          ListTile(
            leading: Icon(Icons.copy),
            title: Text("Copy"),
            onTap: () {
              Clipboard.setData(ClipboardData(text: tag));
              FlashElements.showSnackbar(
                context: context,
                duration: Duration(seconds: 2),
                title: Text(
                  "Copied to clipboard!",
                  style: TextStyle(fontSize: 20)
                ),
                content: Text(
                  tag,
                  style: TextStyle(fontSize: 16)
                ),
                leadingIcon: Icons.copy,
                sideColor: Colors.green,
              );
              Navigator.of(context).pop(true);
            },
          ),
          if(!isHated && !isLoved)
            ListTile(
              leading: Icon(Icons.star, color: Colors.yellow),
              title: Text("Add to Loved"),
              onTap: () {
                settingsHandler.addTagToList('loved', tag);
                parseTags();
                Navigator.of(context).pop(true);
              },
            ),
          if(!isHated && !isLoved)
            ListTile(
              leading: Icon(CupertinoIcons.eye_slash, color: Colors.red),
              title: Text("Add to Hated"),
              onTap: () {
                settingsHandler.addTagToList('hated', tag);
                parseTags();
                Navigator.of(context).pop(true);
              },
            ),
          if(isLoved)
            ListTile(
              leading: Icon(Icons.star),
              title: Text("Remove from Loved"),
              onTap: () {
                settingsHandler.removeTagFromList('loved', tag);
                parseTags();
                Navigator.of(context).pop(true);
              },
            ),
          if(isHated)
            ListTile(
              leading: Icon(CupertinoIcons.eye_slash),
              title: Text("Remove from Hated"),
              onTap: () {
                settingsHandler.removeTagFromList('hated', tag);
                parseTags();
                Navigator.of(context).pop(true);
              },
            ),
        ]
      ),
    );
  }

  Widget tagsBuild() {
    return ListView.builder(
      physics: NeverScrollableScrollPhysics(), // required to allow singlechildscrollview to take control of scrolling
      shrinkWrap: true,
      itemCount: widget.booruItem.tagsList.length,
      itemBuilder: (BuildContext context, int index) {
        String currentTag = widget.booruItem.tagsList[index];

        bool isHated = hatedAndLovedTags[0].contains(currentTag);
        bool isLoved = hatedAndLovedTags[1].contains(currentTag);
        bool isSound = hatedAndLovedTags[2].contains(currentTag);

        List<dynamic> tagIconAndColor = [];
        if (isSound) tagIconAndColor.add([Icons.volume_up_rounded, Colors.white]);
        if (isHated) tagIconAndColor.add([CupertinoIcons.eye_slash, Colors.red]);
        if (isLoved) tagIconAndColor.add([Icons.star, Colors.yellow]);

        if (currentTag != '') {
          return Column(children: <Widget>[
            ListTile(
              onTap: () {
                tagDialog(
                  tag: currentTag,
                  isHated: isHated,
                  isLoved: isLoved
                );
              },
              title: Row(children: [
                if(tagIconAndColor.length > 0)
                  ...[
                    ...tagIconAndColor.map((t) => Icon(t[0], color: t[1])),
                    const SizedBox(width: 5),
                  ],
                MarqueeText(
                  text: currentTag,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  startPadding: 0,
                  isExpanded: true,
                ),
                IconButton(
                  icon: Icon(
                    Icons.add,
                    color: Get.theme.colorScheme.secondary,
                  ),
                  onPressed: () {
                    setState(() {
                      searchHandler.addTag(currentTag);
                    });
                    FlashElements.showSnackbar(
                      context: context,
                      duration: Duration(seconds: 2),
                      title: Text(
                        "Added to search bar:",
                        style: TextStyle(fontSize: 20)
                      ),
                      content: Text(
                        currentTag,
                        style: TextStyle(fontSize: 16)
                      ),
                      leadingIcon: Icons.add,
                      sideColor: Colors.green,
                    );
                  },
                ),
                IconButton(
                  icon: Icon(
                    Icons.fiber_new,
                    color: Get.theme.colorScheme.secondary
                  ),
                  onPressed: () {
                    setState(() {
                      searchHandler.addTabByString(currentTag);
                    });
                    FlashElements.showSnackbar(
                      context: context,
                      duration: Duration(seconds: 2),
                      title: Text(
                        "Added new tab:",
                        style: TextStyle(fontSize: 20)
                      ),
                      content: Text(
                        currentTag,
                        style: TextStyle(fontSize: 16)
                      ),
                      leadingIcon: Icons.fiber_new,
                      sideColor: Colors.green,
                    );
                  },
                ),
              ])
            ),
            Divider(
              color: Colors.grey[800],
              height: 2,
            ),
          ]);
        } else {
          // Render nothing if currentTag is an empty string
          return const SizedBox();
        }
      });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(5, 5, 5, 0),
      child: Scrollbar(
        controller: scrollController,
        interactive: false,
        thickness: 4,
        radius: Radius.circular(10),
        isAlwaysShown: true,
        child: SingleChildScrollView(
          controller: scrollController,
          child: Column(
            children: [
              infoBuild(),
              tagsBuild(),
            ]
          )
        )
      )
    );
  }
}
