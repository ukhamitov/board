import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:flutter_boardview/board_item.dart';
import 'package:flutter_boardview/boardview.dart';

typedef OnDropList = void Function(int? listIndex, int? oldListIndex);
typedef OnTapList = void Function(int? listIndex);
typedef OnStartDragList = void Function(int? listIndex);

class BoardList extends StatefulWidget {
  final List<Widget>? header;
  final Widget? footer;
  final List<BoardItem>? items;
  final Color? backgroundColor;
  final Color? headerBackgroundColor;
  final BoardViewState? boardView;
  final OnDropList? onDropList;
  final OnTapList? onTapList;
  final OnStartDragList? onStartDragList;
  final BoxScrollView Function(NullableIndexedWidgetBuilder itemBuilder)? listBuilder;
  final bool draggable;
  final EdgeInsets? listMargin;
  final Decoration? listDecoration;
  final bool isDragTarget;
  final Decoration? listDecorationWhenDragOver;
  final Decoration? listDecorationWhenEmpty;

  const BoardList({
    Key? key,
    this.header,
    this.items,
    this.footer,
    this.backgroundColor,
    this.headerBackgroundColor,
    this.boardView,
    this.draggable = true,
    this.index,
    this.onDropList,
    this.onTapList,
    this.onStartDragList,
    this.listBuilder,
    this.listDecoration,
    this.listMargin,
    this.isDragTarget = false,
    this.listDecorationWhenDragOver,
    this.listDecorationWhenEmpty,
  }) : super(key: key);

  final int? index;

  @override
  State<StatefulWidget> createState() {
    return BoardListState();
  }
}

class BoardListState extends State<BoardList> with AutomaticKeepAliveClientMixin {
  List<Widget>? _header;
  List<BoardItemState> itemStates = [];
  ScrollController boardListController = ScrollController();

  @override
  void initState() {
    setState(() {
      _header = widget.header;
    });
    super.initState();
  }

  @override
  void didUpdateWidget(covariant BoardList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync header from widget so it updates when list data/header changes (e.g. after move)
    if (widget.header != oldWidget.header) {
      setState(() => _header = widget.header);
    }
  }

  void updateHeader(List<Widget>? header) {
    setState(() => _header = header);
  }

  void onDropList(int? listIndex) {
    if (widget.onDropList != null) {
      widget.onDropList!(listIndex, widget.boardView!.startListIndex);
    }
    widget.boardView!.draggedListIndex = null;
    if (widget.boardView!.mounted) {
      widget.boardView!.setState(() {});
    }
  }

  void _startDrag(Widget item, BuildContext context) {
    if (widget.boardView != null && widget.draggable) {
      if (widget.onStartDragList != null) {
        widget.onStartDragList!(widget.index);
      }
      widget.boardView!.startListIndex = widget.index;
      widget.boardView!.height = context.size!.height;
      widget.boardView!.draggedListIndex = widget.index!;
      widget.boardView!.draggedItemIndex = null;
      widget.boardView!.draggedItem = item;
      widget.boardView!.onDropList = onDropList;
      widget.boardView!.run();
      if (widget.boardView!.mounted) {
        widget.boardView!.setState(() {});
      }
    }
  }

  @override
  bool get wantKeepAlive => true;

  Widget  _itemBuilder(ctx, index) {
    if (widget.items![index].boardList == null ||
        widget.items![index].index != index ||
        widget.items![index].boardList!.widget.index != widget.index ||
        widget.items![index].boardList != this) {
      widget.items![index] = BoardItem(
        boardList: this,
        item: widget.items![index].item,
        draggable: widget.items![index].draggable,
        index: index,
        onDropItem: widget.items![index].onDropItem,
        onTapItem: widget.items![index].onTapItem,
        onDragItem: widget.items![index].onDragItem,
        onStartDragItem: widget.items![index].onStartDragItem,
      );
    }
    if (widget.boardView!.draggedItemIndex == index && widget.boardView!.draggedListIndex == widget.index) {
      return Opacity(
        opacity: 0.0,
        child: widget.items![index],
      );
    } else {
      return widget.items![index];
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.boardView!.listStates.length > widget.index!) {
      widget.boardView!.listStates.removeAt(widget.index!);
    }
    widget.boardView!.listStates.insert(widget.index!, this);

    Color? backgroundColor = Theme.of(context).colorScheme.onInverseSurface;
    if (widget.backgroundColor != null) {
      backgroundColor = widget.backgroundColor;
    }
    final bool isEmpty = widget.items == null || widget.items!.isEmpty;
    final effectiveDecoration = isEmpty && widget.listDecorationWhenEmpty != null
        ? widget.listDecorationWhenEmpty!
        : widget.isDragTarget && widget.listDecorationWhenDragOver != null
            ? widget.listDecorationWhenDragOver!
            : widget.listDecoration ?? BoxDecoration(
                  color: backgroundColor,
                  borderRadius: const BorderRadius.all(Radius.circular(24.0)),
                );

    List<Widget> listWidgets = [];
    if (_header != null) {
      Color? headerBackgroundColor = Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4);
      if (widget.headerBackgroundColor != null) {
        headerBackgroundColor = widget.headerBackgroundColor;
      }
      listWidgets.add(GestureDetector(
          onTap: () {
            if (widget.onTapList != null) {
              widget.onTapList!(widget.index);
            }
          },
          onTapDown: (otd) {
            if (widget.draggable) {
              RenderBox object = context.findRenderObject() as RenderBox;
              Offset pos = object.localToGlobal(Offset.zero);
              widget.boardView!.initialX = pos.dx;
              widget.boardView!.initialY = pos.dy;

              widget.boardView!.rightListX = pos.dx + object.size.width;
              widget.boardView!.leftListX = pos.dx;
            }
          },
          onTapCancel: () {},
          onLongPress: () {
            if (!widget.boardView!.widget.isSelecting && widget.draggable) {
              _startDrag(widget, context);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: headerBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(mainAxisSize: MainAxisSize.max, mainAxisAlignment: MainAxisAlignment.center, children: _header!),
          )));
    }
    // Show list area (header + bordered frame) even when list is empty or null
    final listContent = widget.items != null
        ? (widget.listBuilder != null
            ? widget.listBuilder!(_itemBuilder)
            : ListView.builder(
                shrinkWrap: true,
                physics: const AlwaysScrollableScrollPhysics(),
                controller: boardListController,
                itemCount: widget.items!.length,
                itemBuilder: _itemBuilder,
              ))
        : null;
    final bool isColumnDragTarget = widget.boardView!.draggedListIndex == widget.index &&
        widget.boardView!.draggedItemIndex != null;
    // Match list container corner radius so blur does not overlap the dashed border
    const BorderRadius listBorderRadius = BorderRadius.all(Radius.circular(24.0));
    Widget listArea = Container(
      decoration: effectiveDecoration,
      child: isColumnDragTarget && listContent != null
          ? Stack(
              children: [
                listContent,
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: listBorderRadius,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                      child: const ColoredBox(color: Color(0x00000000)),
                    ),
                  ),
                ),
              ],
            )
          : (listContent ?? const SizedBox.shrink()),
    );
    if (isEmpty) {
      listArea = ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 80),
        child: listArea,
      );
    }
    listWidgets.add(Flexible(
        fit: FlexFit.tight,
        child: listArea));

    if (widget.footer != null) {
      listWidgets.add(widget.footer!);
    }

    return Container(
          margin: widget.listMargin ?? const EdgeInsets.only(left: 10.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: listWidgets,
          ));
  }
}
