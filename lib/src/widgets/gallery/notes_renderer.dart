import 'dart:async';

import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:preload_page_view/preload_page_view.dart';

import 'package:lolisnatcher/src/data/booru_item.dart';
import 'package:lolisnatcher/src/handlers/search_handler.dart';
import 'package:lolisnatcher/src/handlers/settings_handler.dart';
import 'package:lolisnatcher/src/handlers/viewer_handler.dart';
import 'package:lolisnatcher/src/utils/debouncer.dart';
import 'package:lolisnatcher/src/utils/html_parse.dart';
import 'package:lolisnatcher/src/widgets/common/flash_elements.dart';
import 'package:lolisnatcher/src/widgets/common/settings_widgets.dart';
import 'package:lolisnatcher/src/widgets/common/transparent_pointer.dart';

class NotesRenderer extends StatefulWidget {
  const NotesRenderer(this.pageController, {super.key});
  final PreloadPageController? pageController;

  @override
  State<NotesRenderer> createState() => _NotesRendererState();
}

class _NotesRendererState extends State<NotesRenderer> {
  final SearchHandler searchHandler = SearchHandler.instance;
  final SettingsHandler settingsHandler = SettingsHandler.instance;
  final ViewerHandler viewerHandler = ViewerHandler.instance;

  late BooruItem item;
  late double screenWidth,
      screenHeight,
      screenRatio,
      imageWidth,
      imageHeight,
      imageRatio,
      screenToImageRatio,
      offsetX,
      offsetY,
      viewOffsetX,
      viewOffsetY,
      pageOffset,
      resizeScale;
  bool loading = false, shouldScale = false;

  StreamSubscription<BooruItem>? itemListener;
  StreamSubscription? viewStateListener;

  @override
  void initState() {
    super.initState();

    shouldScale = settingsHandler.galleryMode == 'Sample' || !settingsHandler.disableImageScaling;

    screenWidth = WidgetsBinding.instance.platformDispatcher.views.first.physicalSize.width;
    screenHeight = WidgetsBinding.instance.platformDispatcher.views.first.physicalSize.height;
    screenRatio = screenWidth / screenHeight;

    item = searchHandler.viewedItem.value;
    doCalculations(); // trigger calculations on init even if there is no item to init all values
    loadNotes();
    itemListener = searchHandler.viewedItem.listen((BooruItem item) {
      // TODO doesn't trigger for the first item after changing tabs on desktop
      this.item = item;
      updateState();
      loadNotes();
    });

    viewStateListener = viewerHandler.viewState.listen((_) {
      triggerCalculations();
    });

    widget.pageController?.addListener(triggerCalculations);
  }

  void updateState() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.pageController?.removeListener(triggerCalculations);
    itemListener?.cancel();
    viewStateListener?.cancel();
    Debounce.cancel('notes_calculations');
    super.dispose();
  }

  Future<void> loadNotes() async {
    final handler = searchHandler.currentBooruHandler;
    final bool hasSupport = handler.hasNotesSupport;
    final bool hasNotes = item.hasNotes == true;
    // final bool alreadyLoaded = item.notes.isNotEmpty;

    if (item.fileURL.isEmpty || !hasSupport || !hasNotes) {
      loading = false;
      updateState();
      return;
    }

    if (loading) {
      return;
    }
    loading = true;

    item.notes.value = await searchHandler.currentBooruHandler.getNotes(item.serverId!);

    triggerCalculations();

    loading = false;
    updateState();
  }

  void triggerCalculations() {
    // debounce to prevent unnecessary calculations, especially when resizing
    // lessens the impact on performance, but causes notes to be a bit shake-ey when resizing
    Debounce.delay(
      tag: 'notes_calculations',
      callback: () {
        doCalculations();
        updateState();
      },
      duration: const Duration(milliseconds: 50),
    );
  }

  void doCalculations() {
    // do the calculations depending on the current item here
    imageWidth = viewerHandler.viewState.value?.scaleBoundaries?.childSize.width ?? item.fileWidth ?? screenWidth;
    imageHeight = viewerHandler.viewState.value?.scaleBoundaries?.childSize.height ?? item.fileHeight ?? screenHeight;
    imageRatio = imageWidth / imageHeight;

    resizeScale = 1;
    if (shouldScale && item.fileWidth != null && item.fileHeight != null && imageWidth != 0 && imageHeight != 0) {
      resizeScale = imageWidth / item.fileWidth!;
    }

    final viewScale = viewerHandler.viewState.value?.scale;
    screenToImageRatio = viewScale ?? (screenRatio > imageRatio ? (screenWidth / imageWidth) : (screenHeight / imageHeight));

    final double page = widget.pageController?.hasClients == true ? (widget.pageController!.page ?? 0) : 0;
    pageOffset = ((page * 10000).toInt() % 10000) / 10000;
    pageOffset = pageOffset > 0.5 ? (1 - pageOffset) : (0 - pageOffset);
    final bool isVertical = settingsHandler.galleryScrollDirection == 'Vertical';

    offsetX = (screenWidth / 2) - (imageWidth / 2 * screenToImageRatio);
    offsetX = isVertical ? offsetX : (offsetX + (pageOffset * screenWidth));

    offsetY = (screenHeight / 2) - (imageHeight / 2 * screenToImageRatio);
    offsetY = isVertical ? (offsetY + (pageOffset * screenHeight)) : offsetY;

    viewOffsetX = viewerHandler.viewState.value?.position.dx ?? 0;
    viewOffsetY = viewerHandler.viewState.value?.position.dy ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (screenWidth != constraints.maxWidth || screenHeight != constraints.maxHeight) {
          screenWidth = constraints.maxWidth;
          screenHeight = constraints.maxHeight;
          screenRatio = screenWidth / screenHeight;
          triggerCalculations();
        }

        return Obx(() {
          if (!viewerHandler.isLoaded.value || !viewerHandler.showNotes.value || item.fileURL.isEmpty) {
            return const SizedBox();
          } else {
            return Stack(
              children: [
                if (loading)
                  Positioned(
                    left: 60,
                    top: kToolbarHeight * 1.5,
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                          Icon(
                            Icons.note_add,
                            size: 18,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...item.notes.map(
                    (note) => NoteBuild(
                      text: note.content,
                      left: (note.posX * resizeScale * screenToImageRatio) + offsetX + viewOffsetX,
                      top: (note.posY * resizeScale * screenToImageRatio) + offsetY + viewOffsetY,
                      width: note.width * resizeScale * screenToImageRatio,
                      height: note.height * resizeScale * screenToImageRatio,
                    ),
                  ),
              ],
            );
          }
        });
      },
    );
  }
}

class NoteBuild extends StatefulWidget {
  const NoteBuild({
    required this.text,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    super.key,
  });

  final String? text;
  final double left;
  final double top;
  final double width;
  final double height;

  @override
  State<NoteBuild> createState() => _NoteBuildState();
}

class _NoteBuildState extends State<NoteBuild> {
  bool isVisible = true;

  @override
  Widget build(BuildContext context) {
    // TODO don't render when box is out of the screen
    // final screen = MediaQuery.of(context).size;
    // if (widget.left < (0 - widget.width - 30) ||
    //     widget.top < (0 - widget.height - 30) ||
    //     widget.left > (screen.width + 30) ||
    //     widget.top > (screen.height + 30)) {
    //   return const SizedBox.shrink();
    // }

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 10),
      left: widget.left,
      top: widget.top,
      child: TransparentPointer(
        child: GestureDetector(
          onLongPressStart: (details) {
            setState(() {
              isVisible = false;
            });
          },
          onLongPressEnd: (details) {
            setState(() {
              isVisible = true;
            });
          },
          onLongPressCancel: () {
            setState(() {
              isVisible = true;
            });
          },
          onTap: () {
            FlashElements.showSnackbar(
              title: const Text('Note'),
              content: Text.rich(
                parse(
                  widget.text ?? '',
                  const TextStyle(
                    fontSize: 14,
                  ),
                  false,
                ),
                overflow: TextOverflow.fade,
              ),
              duration: null,
              sideColor: Colors.blue,
              shouldLeadingPulse: false,
              asDialog: true,
            );
          },
          behavior: HitTestBehavior.translucent,
          child: AnimatedOpacity(
            opacity: isVisible ? 1 : 0,
            duration: const Duration(milliseconds: 100),
            child: Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF300).withOpacity(0.25),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(
                  color: const Color(0xFFFFF176).withOpacity(0.5),
                ),
              ),
              child: (widget.width > 30 && widget.height > 30) // don't show if too small
                  ? Text.rich(
                      parse(
                        widget.text ?? '',
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        true,
                      ),
                      overflow: TextOverflow.fade,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class NotesDialog extends StatelessWidget {
  const NotesDialog(this.item, {super.key});
  final BooruItem item;

  @override
  Widget build(BuildContext context) {
    return SettingsDialog(
      title: const Text('Notes'),
      content: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Material(
          child: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              itemCount: item.notes.length,
              itemBuilder: (context, index) {
                final note = item.notes[index];
                return ListTile(
                  title: Text.rich(
                    parse(
                      note.content ?? '',
                      const TextStyle(
                        fontSize: 14,
                      ),
                      false,
                    ),
                  ),
                  subtitle: Text('X:${note.posX}, Y:${note.posY}'),
                  shape: Border(
                    bottom: BorderSide(
                      color: Colors.grey.shade600,
                      width: 1,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
      contentPadding: const EdgeInsets.all(12),
      // titlePadding: const EdgeInsets.fromLTRB(6, 18, 2, 6),
      // insetPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 20),
      scrollable: false,
      actionButtons: [
        ElevatedButton(
          child: const Text('Close'),
          onPressed: () {
            Navigator.of(context).pop(false);
          },
        ),
      ],
    );
  }
}
