import 'package:appflowy/plugins/document/presentation/editor_plugins/base/emoji_picker_button.dart';
import 'package:appflowy/workspace/application/tabs/tabs_bloc.dart';
import 'package:appflowy/workspace/application/view/view_ext.dart';
import 'package:appflowy/workspace/application/view/view_listener.dart';
import 'package:appflowy/workspace/application/view/view_service.dart';
import 'package:appflowy_backend/protobuf/flowy-folder2/view.pb.dart';
import 'package:appflowy_popover/appflowy_popover.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// workspaces / ... / view_title
class ViewTitleBar extends StatefulWidget {
  const ViewTitleBar({
    super.key,
    required this.view,
  });

  final ViewPB view;

  @override
  State<ViewTitleBar> createState() => _ViewTitleBarState();
}

class _ViewTitleBarState extends State<ViewTitleBar> {
  late Future<List<ViewPB>> ancestors;

  @override
  void initState() {
    super.initState();

    ancestors = widget.view.getAncestors(
      includeSelf: true,
    );
  }

  @override
  void didUpdateWidget(covariant ViewTitleBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.view.id != widget.view.id) {
      ancestors = widget.view.getAncestors(
        includeSelf: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ViewPB>>(
      future: ancestors,
      builder: ((context, snapshot) {
        final ancestors = snapshot.data;
        if (ancestors == null ||
            snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        return Row(
          children: _buildViewTitles(ancestors),
        );
      }),
    );
  }

  List<Widget> _buildViewTitles(List<ViewPB> views) {
    final children = <Widget>[];
    for (var i = 0; i < views.length; i++) {
      final view = views[i];
      children.add(
        _ViewTitle(
          view: view,
          behavior: i == views.length - 1
              ? _ViewTitleBehavior.editable // only the last one is editable
              : _ViewTitleBehavior.uneditable, // others are not editable
        ),
      );
      if (i != views.length - 1) {
        // if not the last one, add a divider
        children.add(const FlowyText.regular('/'));
      }
    }
    return children;
  }
}

enum _ViewTitleBehavior {
  editable,
  uneditable,
}

class _ViewTitle extends StatefulWidget {
  const _ViewTitle({
    required this.view,
    this.behavior = _ViewTitleBehavior.editable,
  });

  final ViewPB view;
  final _ViewTitleBehavior behavior;

  @override
  State<_ViewTitle> createState() => _ViewTitleState();
}

class _ViewTitleState extends State<_ViewTitle> {
  final popoverController = PopoverController();
  final textEditingController = TextEditingController();
  late final viewListener = ViewListener(viewId: widget.view.id);

  String name = '';
  String icon = '';

  @override
  void initState() {
    super.initState();

    name = widget.view.name;
    icon = widget.view.icon.value;

    _resetTextEditingController();
    viewListener.start(
      onViewUpdated: (view) {
        setState(() {
          name = view.name;
          icon = view.icon.value;
          _resetTextEditingController();
        });
      },
    );
  }

  @override
  void dispose() {
    textEditingController.dispose();
    popoverController.close();
    viewListener.stop();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // root view
    if (widget.view.parentViewId.isEmpty) {
      return Row(
        children: [
          FlowyText.regular(name),
          const HSpace(4.0),
        ],
      );
    }

    final child = Row(
      children: [
        FlowyText.regular(
          icon,
          fontSize: 18.0,
        ),
        const HSpace(2.0),
        FlowyText.regular(name),
      ],
    );

    if (widget.behavior == _ViewTitleBehavior.uneditable) {
      return FlowyButton(
        useIntrinsicWidth: true,
        onTap: () {
          context.read<TabsBloc>().openPlugin(widget.view);
        },
        text: child,
      );
    }

    return AppFlowyPopover(
      constraints: const BoxConstraints(
        maxWidth: 300,
        maxHeight: 44,
      ),
      controller: popoverController,
      direction: PopoverDirection.bottomWithCenterAligned,
      offset: const Offset(0, 18),
      popupBuilder: (context) {
        // icon + textfield
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            EmojiPickerButton(
              emoji: icon,
              defaultIcon: widget.view.defaultIcon(),
              direction: PopoverDirection.bottomWithCenterAligned,
              offset: const Offset(0, 18),
              onSubmitted: (emoji, _) {
                ViewBackendService.updateViewIcon(
                  viewId: widget.view.id,
                  viewIcon: emoji,
                );
                popoverController.close();
              },
            ),
            const HSpace(4.0),
            SizedBox(
              height: 36.0,
              width: 220,
              child: FlowyTextField(
                autoFocus: true,
                controller: textEditingController,
                onSubmitted: (text) {
                  if (text.isNotEmpty && text != name) {
                    ViewBackendService.updateView(
                      viewId: widget.view.id,
                      name: text,
                    );
                    popoverController.close();
                  }
                },
              ),
            ),
            const HSpace(4.0),
          ],
        );
      },
      child: FlowyButton(
        useIntrinsicWidth: true,
        text: child,
      ),
    );
  }

  void _resetTextEditingController() {
    textEditingController
      ..text = name
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: name.length,
      );
  }
}
