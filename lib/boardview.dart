library flutter_boardview;

import 'dart:core';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_boardview/board_list.dart';
import 'package:flutter_boardview/boardview_controller.dart';

class BoardView extends StatefulWidget {
  final List<BoardList>? lists;
  final double width;
  final Widget? middleWidget;
  final double? bottomPadding;
  final bool isSelecting;
  final BoardViewController? boardViewController;
  final int dragDelay;
  final EdgeInsets? listMargin;
  final Decoration? listDecoration;
  /// When non-null, used for the list (column) over which an item is being dragged.
  final Decoration? listDecorationWhenDragOver;
  /// Decoration when the list has no items (e.g. dashed border for empty drop zone).
  final Decoration? listDecorationWhenEmpty;
  /// When non-null, applied to the widget shown while dragging an item.
  final Decoration? draggedItemDecoration;

  final Function(bool)? itemInMiddleWidget;
  final OnDropBottomWidget? onDropItemInMiddleWidget;
  final ScrollController? scrollController;

  const BoardView({
    Key? key,
    this.itemInMiddleWidget,
    this.boardViewController,
    this.dragDelay = 300,
    this.onDropItemInMiddleWidget,
    this.isSelecting = false,
    this.lists,
    this.listMargin,
    this.listDecoration,
    this.listDecorationWhenDragOver,
    this.listDecorationWhenEmpty,
    this.draggedItemDecoration,
    this.width = 280,
    this.middleWidget,
    this.bottomPadding,
    this.scrollController,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return BoardViewState();
  }
}

typedef OnDropBottomWidget = void Function(
    int? listIndex, int? itemIndex, double percentX);
typedef OnDropItem = void Function(int? listIndex, int? itemIndex);
typedef OnDropList = void Function(int? listIndex);

class BoardViewState extends State<BoardView>
    with AutomaticKeepAliveClientMixin {
  Widget? draggedItem;
  int? draggedItemIndex;
  int? draggedListIndex;
  double? dx;
  double? dxInit;
  double? dyInit;
  double? dy;
  double? offsetX;
  double? offsetY;
  double? initialX = 0;
  double? initialY = 0;
  double? rightListX;
  double? leftListX;
  double? topListY;
  double? bottomListY;
  double? topItemY;
  double? bottomItemY;
  double? height;
  int? startListIndex;
  int? startItemIndex;

  bool canDrag = true;

  /// Returns true if [draggedListIndex] and (for item drag) [draggedItemIndex]
  /// are within current [widget.lists] and [listStates] bounds.
  bool _isDragIndexInBounds() {
    if (widget.lists == null || widget.lists!.isEmpty) return false;
    final listCount = widget.lists!.length;
    if (draggedListIndex == null ||
        draggedListIndex! < 0 ||
        draggedListIndex! >= listCount) return false;
    if (listStates.length != listCount) return false;
    if (draggedItemIndex != null) {
      final list = widget.lists![draggedListIndex!];
      final itemStates = listStates[draggedListIndex!].itemStates;
      final itemsLength = list.items?.length ?? 0;
      if (draggedItemIndex! < 0 ||
          draggedItemIndex! >= itemStates.length ||
          draggedItemIndex! >= itemsLength) {
        return false;
      }
    }
    return true;
  }

  /// Schedules reset of [canDrag] after [BoardView.dragDelay]. Call whenever
  /// [canDrag] is set to false so the board does not stay stuck (e.g. when
  /// animation has no clients or whenComplete throws).
  void _scheduleCanDragReset() {
    Future.delayed(Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          canDrag = true;
        });
      }
    });
  }

  late ScrollController boardViewController;

  List<BoardListState> listStates = [];

  OnDropItem? onDropItem;
  OnDropList? onDropList;

  bool isScrolling = false;

  bool _isInWidget = false;

  final GlobalKey _middleWidgetKey = GlobalKey();

  // ignore: prefer_typing_uninitialized_variables
  var pointer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (widget.boardViewController != null) {
      widget.boardViewController!.state = this;
    }
    boardViewController = widget.scrollController ?? ScrollController();
  }

  void moveListRight() {
    if (!_isDragIndexInBounds() || draggedItemIndex != null) return;
    var list = widget.lists![draggedListIndex!];
    var listState = listStates[draggedListIndex!];
    widget.lists!.removeAt(draggedListIndex!);
    listStates.removeAt(draggedListIndex!);
    if (draggedListIndex != null) {
      draggedListIndex = draggedListIndex! + 1;
    }
    widget.lists!.insert(draggedListIndex!, list);
    listStates.insert(draggedListIndex!, listState);
    canDrag = false;
    _scheduleCanDragReset();
    if (boardViewController.hasClients) {
      int? tempListIndex = draggedListIndex;
      boardViewController
          .animateTo(draggedListIndex! * widget.width,
              duration: const Duration(milliseconds: 100), curve: Curves.ease)
          .whenComplete(() {
        try {
          if (!mounted || tempListIndex! >= listStates.length) return;
          final RenderBox object =
              listStates[tempListIndex].context.findRenderObject() as RenderBox;
          final Offset pos = object.localToGlobal(Offset.zero);
          leftListX = pos.dx;
          rightListX = pos.dx + object.size.width;
        } catch (_) {
          // Ignore; canDrag already scheduled via _scheduleCanDragReset
        }
      });
    }
    if (mounted) {
      setState(() {});
    }
  }

  void moveRight() {
    if (!_isDragIndexInBounds() || draggedItemIndex == null) return;
    var item = widget.lists![draggedListIndex!].items![draggedItemIndex!];
    var itemState = listStates[draggedListIndex!].itemStates[draggedItemIndex!];
    widget.lists![draggedListIndex!].items!.removeAt(draggedItemIndex!);
    listStates[draggedListIndex!].itemStates.removeAt(draggedItemIndex!);
    if (listStates[draggedListIndex!].mounted) {
      listStates[draggedListIndex!].setState(() {});
    }
    if (draggedListIndex != null) {
      draggedListIndex = draggedListIndex! + 1;
    }
    // Append to target list. Use min of both lengths so we never insert past
    // either list (items and itemStates can be out of sync across rebuilds).
    final targetListState = listStates[draggedListIndex!];
    final targetItems = widget.lists![draggedListIndex!].items!;
    final insertAt = targetListState.itemStates.length < targetItems.length
        ? targetListState.itemStates.length
        : targetItems.length;
    draggedItemIndex = insertAt;
    targetItems.insert(draggedItemIndex!, item);
    targetListState.itemStates.insert(draggedItemIndex!, itemState);
    canDrag = false;
    _scheduleCanDragReset();
    if (listStates[draggedListIndex!].mounted) {
      listStates[draggedListIndex!].setState(() {});
    }
    if (boardViewController.hasClients) {
      int? tempListIndex = draggedListIndex;
      int? tempItemIndex = draggedItemIndex;
      boardViewController
          .animateTo(draggedListIndex! * widget.width,
              duration: const Duration(milliseconds: 100), curve: Curves.ease)
          .whenComplete(() {
        try {
          if (!mounted ||
              tempListIndex! >= listStates.length ||
              tempItemIndex! >= listStates[tempListIndex].itemStates.length) {
            return;
          }
          final RenderBox object =
              listStates[tempListIndex].context.findRenderObject() as RenderBox;
          final Offset pos = object.localToGlobal(Offset.zero);
          leftListX = pos.dx;
          rightListX = pos.dx + object.size.width;
          final RenderBox box = listStates[tempListIndex]
              .itemStates[tempItemIndex]
              .context
              .findRenderObject() as RenderBox;
          final Offset itemPos = box.localToGlobal(Offset.zero);
          topItemY = itemPos.dy;
          bottomItemY = itemPos.dy + box.size.height;
        } catch (_) {
          // Ignore; canDrag already scheduled via _scheduleCanDragReset
        }
      });
    }
    if (mounted) {
      setState(() {});
    }
  }

  void moveListLeft() {
    if (!_isDragIndexInBounds() || draggedItemIndex != null) return;
    var list = widget.lists![draggedListIndex!];
    var listState = listStates[draggedListIndex!];
    widget.lists!.removeAt(draggedListIndex!);
    listStates.removeAt(draggedListIndex!);
    if (draggedListIndex != null) {
      draggedListIndex = draggedListIndex! - 1;
    }
    widget.lists!.insert(draggedListIndex!, list);
    listStates.insert(draggedListIndex!, listState);
    canDrag = false;
    _scheduleCanDragReset();
    if (boardViewController.hasClients) {
      int? tempListIndex = draggedListIndex;
      boardViewController
          .animateTo(draggedListIndex! * widget.width,
              duration: Duration(milliseconds: widget.dragDelay),
              curve: Curves.ease)
          .whenComplete(() {
        try {
          if (!mounted || tempListIndex! >= listStates.length) return;
          final RenderBox object =
              listStates[tempListIndex].context.findRenderObject() as RenderBox;
          final Offset pos = object.localToGlobal(Offset.zero);
          leftListX = pos.dx;
          rightListX = pos.dx + object.size.width;
        } catch (_) {
          // Ignore; canDrag already scheduled via _scheduleCanDragReset
        }
      });
    }
    if (mounted) {
      setState(() {});
    }
  }

  void moveLeft() {
    if (!_isDragIndexInBounds() || draggedItemIndex == null) return;
    var item = widget.lists![draggedListIndex!].items![draggedItemIndex!];
    var itemState = listStates[draggedListIndex!].itemStates[draggedItemIndex!];
    widget.lists![draggedListIndex!].items!.removeAt(draggedItemIndex!);
    listStates[draggedListIndex!].itemStates.removeAt(draggedItemIndex!);
    if (listStates[draggedListIndex!].mounted) {
      listStates[draggedListIndex!].setState(() {});
    }
    if (draggedListIndex != null) {
      draggedListIndex = draggedListIndex! - 1;
    }
    // Append to target list. Use min of both lengths so we never insert past
    // either list (items and itemStates can be out of sync across rebuilds).
    final targetListState = listStates[draggedListIndex!];
    final targetItems = widget.lists![draggedListIndex!].items!;
    final insertAt = targetListState.itemStates.length < targetItems.length
        ? targetListState.itemStates.length
        : targetItems.length;
    draggedItemIndex = insertAt;
    targetItems.insert(draggedItemIndex!, item);
    targetListState.itemStates.insert(draggedItemIndex!, itemState);
    canDrag = false;
    _scheduleCanDragReset();
    if (listStates[draggedListIndex!].mounted) {
      listStates[draggedListIndex!].setState(() {});
    }
    if (boardViewController.hasClients) {
      int? tempListIndex = draggedListIndex;
      int? tempItemIndex = draggedItemIndex;
      boardViewController
          .animateTo(draggedListIndex! * widget.width,
              duration: const Duration(milliseconds: 100), curve: Curves.ease)
          .whenComplete(() {
        try {
          if (!mounted ||
              tempListIndex! >= listStates.length ||
              tempItemIndex! >= listStates[tempListIndex].itemStates.length) {
            return;
          }
          final RenderBox object =
              listStates[tempListIndex].context.findRenderObject() as RenderBox;
          final Offset pos = object.localToGlobal(Offset.zero);
          leftListX = pos.dx;
          rightListX = pos.dx + object.size.width;
          final RenderBox box = listStates[tempListIndex]
              .itemStates[tempItemIndex]
              .context
              .findRenderObject() as RenderBox;
          final Offset itemPos = box.localToGlobal(Offset.zero);
          topItemY = itemPos.dy;
          bottomItemY = itemPos.dy + box.size.height;
        } catch (_) {
          // Ignore; canDrag already scheduled via _scheduleCanDragReset
        }
      });
    }
    if (mounted) {
      setState(() {});
    }
  }

  bool shown = true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // if (kDebugMode) {
    //   print("dy:$dy");
    //   print("topListY:$topListY");
    //   print("bottomListY:$bottomListY");
    // }
    if (boardViewController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((Duration duration) {
        if (!mounted) return;
        try {
          if (boardViewController.hasClients) {
            boardViewController.position.didUpdateScrollPositionBy(0);
          }
        } catch (e) {
          if (kDebugMode) {
            print(e.toString());
          }
        }
        if (boardViewController.hasClients) {
          bool scrollShown = boardViewController.position.maxScrollExtent != 0;
          if (scrollShown != shown && mounted) {
            setState(() {
              shown = scrollShown;
            });
          }
        }
      });
    }
    Widget listWidget = ListView.builder(
      physics: const ClampingScrollPhysics(),
      itemCount: widget.lists!.length,
      scrollDirection: Axis.horizontal,
      controller: boardViewController,
      itemBuilder: (BuildContext context, int index) {
        final isListEmpty = widget.lists![index].items?.isEmpty == true;
        final isDragTarget = draggedListIndex == index && draggedItemIndex != null;
        final listDecoration = (isDragTarget &&
            widget.listDecorationWhenDragOver != null
            ? widget.listDecorationWhenDragOver! : isListEmpty &&
            widget.listDecorationWhenEmpty != null ? widget.listDecorationWhenEmpty! :
            widget.listDecoration);
        if (widget.lists![index].boardView == null) {
          widget.lists![index] = BoardList(
            key: widget.lists![index].key,
            items: widget.lists![index].items,
            headerBackgroundColor: widget.lists![index].headerBackgroundColor,
            backgroundColor: widget.lists![index].backgroundColor,
            footer: widget.lists![index].footer,
            header: widget.lists![index].header,
            boardView: this,
            draggable: widget.lists![index].draggable,
            onDropList: widget.lists![index].onDropList,
            onTapList: widget.lists![index].onTapList,
            onStartDragList: widget.lists![index].onStartDragList,
            listBuilder: widget.lists![index].listBuilder,
            listMargin: widget.listMargin,
            listDecoration: listDecoration ?? const BoxDecoration(),
          );
        }
        if (widget.lists![index].index != index ||
            widget.lists![index].listDecoration != listDecoration) {
          widget.lists![index] = BoardList(
            key: widget.lists![index].key,
            items: widget.lists![index].items,
            headerBackgroundColor: widget.lists![index].headerBackgroundColor,
            backgroundColor: widget.lists![index].backgroundColor,
            footer: widget.lists![index].footer,
            header: widget.lists![index].header,
            boardView: this,
            draggable: widget.lists![index].draggable,
            index: index,
            onDropList: widget.lists![index].onDropList,
            onTapList: widget.lists![index].onTapList,
            onStartDragList: widget.lists![index].onStartDragList,
            listBuilder: widget.lists![index].listBuilder,
            listMargin: widget.listMargin,
            listDecoration: listDecoration ?? const BoxDecoration(),
          );
        }

        var temp = Container(
            width: widget.width,
            padding: EdgeInsets.fromLTRB(0, 0, 0, widget.bottomPadding ?? 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[Expanded(child: widget.lists![index])],
            ));
        if (draggedListIndex == index && draggedItemIndex == null) {
          return Opacity(
            opacity: 0.0,
            child: temp,
          );
        } else {
          return temp;
        }
      },
    );

    List<Widget> stackWidgets = <Widget>[listWidget];
    bool isInBottomWidget = false;
    if (dy != null) {
      if (MediaQuery.of(context).size.height - dy! < 80) {
        isInBottomWidget = true;
      }
    }
    if (widget.itemInMiddleWidget != null && _isInWidget != isInBottomWidget) {
      widget.itemInMiddleWidget!(isInBottomWidget);
      _isInWidget = isInBottomWidget;
    }
    if (initialX != null &&
        initialY != null &&
        offsetX != null &&
        offsetY != null &&
        dx != null &&
        dy != null &&
        height != null) {
      if (canDrag && dxInit != null && dyInit != null && !isInBottomWidget && _isDragIndexInBounds()) {
        if (draggedItemIndex != null &&
            draggedItem != null &&
            topItemY != null &&
            bottomItemY != null) {
          //dragging item
          if (0 <= draggedListIndex! - 1 && dx! < leftListX! + 45) {
            //scroll left
            if (boardViewController.hasClients) {
              boardViewController.animateTo(
                  boardViewController.position.pixels - 5,
                  duration: const Duration(milliseconds: 10),
                  curve: Curves.ease);
              if (listStates[draggedListIndex!].mounted) {
                RenderBox object = listStates[draggedListIndex!]
                    .context
                    .findRenderObject() as RenderBox;
                Offset pos = object.localToGlobal(Offset.zero);
                leftListX = pos.dx;
                rightListX = pos.dx + object.size.width;
              }
            }
          }
          if (widget.lists!.length > draggedListIndex! + 1 &&
              dx! > rightListX! - 45) {
            //scroll right
            if (boardViewController.hasClients) {
              boardViewController.animateTo(
                  boardViewController.position.pixels + 5,
                  duration: const Duration(milliseconds: 10),
                  curve: Curves.ease);
              if (listStates[draggedListIndex!].mounted) {
                RenderBox object = listStates[draggedListIndex!]
                    .context
                    .findRenderObject() as RenderBox;
                Offset pos = object.localToGlobal(Offset.zero);
                leftListX = pos.dx;
                rightListX = pos.dx + object.size.width;
              }
            }
          }
          if (0 <= draggedListIndex! - 1 && dx! < leftListX!) {
            //move left
            moveLeft();
          }
          if (widget.lists!.length > draggedListIndex! + 1 &&
              dx! > rightListX!) {
            //move right
            moveRight();
          }
          // Vertical list scroll during drag disabled: no auto-scroll when
          // dragging item near top or bottom of list.
          // Position selection disabled: do not reorder items during drag
          // if (0 <= draggedItemIndex! - 1 &&
          //     dy! <
          //         topItemY! -
          //             listStates[draggedListIndex!]
          //                     .itemStates[draggedItemIndex! - 1]
          //                     .height /
          //                 2) {
          //   moveUp();
          // }
        } else {
          //dragging list
          if (0 <= draggedListIndex! - 1 && dx! < leftListX! + 45) {
            //scroll left
            if (boardViewController.hasClients) {
              boardViewController.animateTo(
                  boardViewController.position.pixels - 5,
                  duration: const Duration(milliseconds: 10),
                  curve: Curves.ease);
              if (leftListX != null) {
                leftListX = leftListX! + 5;
              }
              if (rightListX != null) {
                rightListX = rightListX! + 5;
              }
            }
          }

          if (widget.lists!.length > draggedListIndex! + 1 &&
              dx! > rightListX! - 45) {
            //scroll right
            if (boardViewController.hasClients) {
              boardViewController.animateTo(
                  boardViewController.position.pixels + 5,
                  duration: const Duration(milliseconds: 10),
                  curve: Curves.ease);
              if (leftListX != null) {
                leftListX = leftListX! - 5;
              }
              if (rightListX != null) {
                rightListX = rightListX! - 5;
              }
            }
          }
          if (widget.lists!.length > draggedListIndex! + 1 &&
              dx! > rightListX!) {
            //move right
            moveListRight();
          }
          if (0 <= draggedListIndex! - 1 && dx! < leftListX!) {
            //move left
            moveListLeft();
          }
        }
      }
      if (widget.middleWidget != null) {
        stackWidgets
            .add(Container(key: _middleWidgetKey, child: widget.middleWidget));
      }
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        if (mounted) {
          setState(() {});
        }
      });
      final draggedChild = widget.draggedItemDecoration != null
          ? DecoratedBox(
        decoration: widget.draggedItemDecoration!,
        child: Opacity(opacity: .7, child: draggedItem),
      )
          : Opacity(opacity: .7, child: draggedItem);
      stackWidgets.add(Positioned(
        width: widget.width,
        height: height,
        left: (dx! - offsetX!) + initialX!,
        top: (dy! - offsetY!) + initialY!,
        //child: Opacity(opacity: .7, child: draggedItem),
        child: draggedChild,
      ));
    }

    return Listener(
        onPointerMove: (opm) {
          if (draggedItem != null) {
            dxInit ??= opm.position.dx;
            dyInit ??= opm.position.dy;
            dx = opm.position.dx;
            dy = opm.position.dy;
            if (mounted) {
              setState(() {});
            }
          }
        },
        onPointerDown: (opd) {
          RenderBox box = context.findRenderObject() as RenderBox;
          Offset pos = box.localToGlobal(opd.position);
          offsetX = pos.dx;
          offsetY = pos.dy;
          pointer = opd;
          if (mounted) {
            setState(() {});
          }
        },
        onPointerUp: (opu) {
          if (onDropItem != null) {
            int? tempDraggedItemIndex = draggedItemIndex;
            int? tempDraggedListIndex = draggedListIndex;
            int? startDraggedItemIndex = startItemIndex;
            int? startDraggedListIndex = startListIndex;

            if (_isInWidget && widget.onDropItemInMiddleWidget != null) {
              onDropItem!(startDraggedListIndex, startDraggedItemIndex);
              widget.onDropItemInMiddleWidget!(
                  startDraggedListIndex,
                  startDraggedItemIndex,
                  opu.position.dx / MediaQuery.of(context).size.width);
            } else {
              onDropItem!(tempDraggedListIndex, tempDraggedItemIndex);
            }
          }
          if (onDropList != null) {
            int? tempDraggedListIndex = draggedListIndex;
            if (_isInWidget && widget.onDropItemInMiddleWidget != null) {
              onDropList!(tempDraggedListIndex);
              widget.onDropItemInMiddleWidget!(tempDraggedListIndex, null,
                  opu.position.dx / MediaQuery.of(context).size.width);
            } else {
              onDropList!(tempDraggedListIndex);
            }
          }
          draggedItem = null;
          offsetX = null;
          offsetY = null;
          initialX = null;
          initialY = null;
          dx = null;
          dy = null;
          draggedItemIndex = null;
          draggedListIndex = null;
          onDropItem = null;
          onDropList = null;
          dxInit = null;
          dyInit = null;
          leftListX = null;
          rightListX = null;
          topListY = null;
          bottomListY = null;
          topItemY = null;
          bottomItemY = null;
          startListIndex = null;
          startItemIndex = null;
          if (mounted) {
            setState(() {});
          }
        },
        child: Stack(
          children: stackWidgets,
        ));
  }

  void run() {
    if (pointer != null) {
      dx = pointer.position.dx;
      dy = pointer.position.dy;
      if (mounted) {
        setState(() {});
      }
    }
  }
}
