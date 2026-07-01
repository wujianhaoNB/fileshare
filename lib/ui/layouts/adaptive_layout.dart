import 'package:flutter/material.dart';

/// Breakpoints for responsive layout adaptation.
class Breakpoints {
  static const double phone = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
}

/// Detects the current screen size category.
enum ScreenSize { phone, tablet, desktop }

ScreenSize getScreenSize(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  if (width < Breakpoints.phone) return ScreenSize.phone;
  if (width < Breakpoints.tablet) return ScreenSize.tablet;
  return ScreenSize.desktop;
}

/// Adaptive scaffold that shows different layouts based on screen size.
class AdaptiveScaffold extends StatelessWidget {
  final Widget? title;
  final List<Widget>? actions;
  final Widget body;
  final Widget? navigationBar;
  final Widget? sidebar;
  final Widget? detailPane;
  final bool showDetailPane;
  final int selectedIndex;
  final ValueChanged<int>? onDestinationSelected;
  final List<NavigationDestination> destinations;

  const AdaptiveScaffold({
    super.key,
    this.title,
    this.actions,
    required this.body,
    this.navigationBar,
    this.sidebar,
    this.detailPane,
    this.showDetailPane = false,
    this.selectedIndex = 0,
    this.onDestinationSelected,
    this.destinations = const [],
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = getScreenSize(context);

    switch (screenSize) {
      case ScreenSize.phone:
        return _PhoneLayout(
          title: title,
          actions: actions,
          body: body,
          navigationBar: navigationBar ??
              (destinations.isNotEmpty
                  ? NavigationBar(
                      selectedIndex: selectedIndex,
                      onDestinationSelected: onDestinationSelected,
                      destinations: destinations,
                    )
                  : null),
        );

      case ScreenSize.tablet:
        return _TabletLayout(
          title: title,
          actions: actions,
          body: body,
          sidebar: sidebar,
          detailPane: detailPane,
          showDetailPane: showDetailPane,
          destinations: destinations,
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
        );

      case ScreenSize.desktop:
        return _DesktopLayout(
          title: title,
          actions: actions,
          body: body,
          sidebar: sidebar,
          detailPane: detailPane,
          showDetailPane: showDetailPane,
          destinations: destinations,
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
        );
    }
  }
}

/// Phone layout: single column with optional bottom navigation.
class _PhoneLayout extends StatelessWidget {
  final Widget? title;
  final List<Widget>? actions;
  final Widget body;
  final Widget? navigationBar;

  const _PhoneLayout({
    this.title,
    this.actions,
    required this.body,
    this.navigationBar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: title != null || actions != null
          ? AppBar(
              title: title,
              actions: actions,
            )
          : null,
      body: body,
      bottomNavigationBar: navigationBar,
    );
  }
}

/// Tablet layout: sidebar column + main content + optional detail pane.
class _TabletLayout extends StatelessWidget {
  final Widget? title;
  final List<Widget>? actions;
  final Widget body;
  final Widget? sidebar;
  final Widget? detailPane;
  final bool showDetailPane;
  final List<NavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int>? onDestinationSelected;

  const _TabletLayout({
    this.title,
    this.actions,
    required this.body,
    this.sidebar,
    this.detailPane,
    required this.showDetailPane,
    required this.destinations,
    required this.selectedIndex,
    this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: title,
        actions: actions,
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            labelType: NavigationRailLabelType.all,
            destinations: destinations.map((d) => NavigationRailDestination(
              icon: d.icon,
              selectedIcon: d.selectedIcon,
              label: Text(d.label),
            )).toList(),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: body,
          ),
          if (showDetailPane && detailPane != null) ...[
            const VerticalDivider(width: 1),
            SizedBox(
              width: 360,
              child: detailPane!,
            ),
          ],
        ],
      ),
    );
  }
}

/// Desktop layout: full sidebar with master-detail view.
class _DesktopLayout extends StatelessWidget {
  final Widget? title;
  final List<Widget>? actions;
  final Widget body;
  final Widget? sidebar;
  final Widget? detailPane;
  final bool showDetailPane;
  final List<NavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int>? onDestinationSelected;

  const _DesktopLayout({
    this.title,
    this.actions,
    required this.body,
    this.sidebar,
    this.detailPane,
    required this.showDetailPane,
    required this.destinations,
    required this.selectedIndex,
    this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: title,
        actions: actions,
      ),
      body: Row(
        children: [
          SizedBox(
            width: 260,
            child: Column(
              children: [
                if (sidebar != null) Expanded(child: sidebar!),
                if (destinations.isNotEmpty)
                  ...destinations.asMap().entries.map((entry) => ListTile(
                        leading: entry.value.icon,
                        title: Text(entry.value.label),
                        selected: selectedIndex == entry.key,
                        onTap: () => onDestinationSelected?.call(entry.key),
                      )),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            flex: 3,
            child: body,
          ),
          if (showDetailPane && detailPane != null) ...[
            const VerticalDivider(width: 1),
            Expanded(
              flex: 2,
              child: detailPane!,
            ),
          ],
        ],
      ),
    );
  }
}
