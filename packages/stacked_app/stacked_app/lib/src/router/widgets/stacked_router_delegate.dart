import 'package:stacked_app/stacked_app.dart';
import 'package:stacked_app/src/route/page_route_info.dart';
import 'package:stacked_app/src/router/stacked_route_page.dart';
import 'package:stacked_app/src/router/stacked_router_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../../utils.dart';
import '../stacked_router_config.dart';
import '../controller/routing_controller.dart';

mixin StackedRouterDelegate<T> on RouterDelegate<T> {
  RootRouterDelegate get rootDelegate;

  RouterNode get routerNode;
}

class RootRouterDelegate extends RouterDelegate<List<PageRouteInfo>>
    with ChangeNotifier, StackedRouterDelegate<List<PageRouteInfo>>, PopNavigatorRouterDelegateMixin<List<PageRouteInfo>> {
  final List<PageRouteInfo> defaultHistory;
  final GlobalKey<NavigatorState> navigatorKey;
  final RouterNode routerNode;
  final String initialDeepLink;
  final List<NavigatorObserver> navigatorObservers;

  RootRouterDelegate(
    StackedRouterConfig routerConfig, {
    this.defaultHistory,
    this.initialDeepLink,
    this.navigatorObservers,
  })  : assert(initialDeepLink == null || defaultHistory == null),
        assert(routerConfig != null),
        routerNode = routerConfig.root,
        navigatorKey = GlobalKey<NavigatorState>() {
    routerNode.addListener(notifyListeners);
  }

  @override
  List<PageRouteInfo> get currentConfiguration {
    var route = routerNode.topMost.currentRoute;
    if (route == null) {
      return null;
    }
    return route.breadcrumbs.map((d) => d.route).toList(growable: false);
  }

  @override
  Future<void> setInitialRoutePath(List<PageRouteInfo> routes) {
    // setInitialRoutePath is re-fired on enabling
    // select widget mode from flutter inspector,
    // this check is preventing it from rebuilding the app
    if (!routerNode.stackIsEmpty) {
      return SynchronousFuture(null);
    }

    if (!listNullOrEmpty(defaultHistory)) {
      return routerNode.pushAll(defaultHistory);
    } else if (initialDeepLink != null) {
      return routerNode.pushPath(initialDeepLink, includePrefixMatches: true);
    } else if (!listNullOrEmpty(routes)) {
      return routerNode.pushAll(routes);
    } else {
      throw FlutterError("Can not resolve initial route");
    }
  }

  @override
  Future<void> setNewRoutePath(List<PageRouteInfo> routes) {
    if (!listNullOrEmpty(routes)) {
      return routerNode.updateOrReplaceRoutes(routes);
    }
    return SynchronousFuture(null);
  }

  @override
  RootRouterDelegate get rootDelegate => this;

  @override
  Widget build(BuildContext context) {
    return RoutingControllerScope(
      routerNode: routerNode,
      child: routerNode.stack.isEmpty
          ? Container(color: Colors.white)
          : Navigator(
              key: navigatorKey,
              pages: routerNode.stack,
              observers: navigatorObservers,
              onPopPage: (route, result) {
                if (!route.didPop(result)) {
                  return false;
                }
                routerNode.pop();
                return true;
              },
            ),
    );
  }
}

class InnerRouterDelegate extends RouterDelegate
    with ChangeNotifier, PopNavigatorRouterDelegateMixin, StackedRouterDelegate {
  final RootRouterDelegate rootDelegate;
  final GlobalKey<NavigatorState> navigatorKey;
  final RouterNode routerNode;
  final List<NavigatorObserver> navigatorObservers;

  InnerRouterDelegate({
    this.rootDelegate,
    this.routerNode,
    this.navigatorObservers,
    List<PageRouteInfo> defaultRoutes,
  })  : assert(routerNode != null),
        navigatorKey = GlobalKey<NavigatorState>() {
    routerNode.addListener(() {
      notifyListeners();
      rootDelegate.notifyListeners();
    });
    pushInitialRoutes(defaultRoutes);
  }

  @override
  Widget build(BuildContext context) {
    return RoutingControllerScope(
      routerNode: routerNode,
      child: routerNode.stack.isEmpty
          ? Container(color: Colors.white)
          : Navigator(
              key: navigatorKey,
              pages: routerNode.stack,
              observers: navigatorObservers,
              onPopPage: (route, result) {
                if (!route.didPop(result)) {
                  return false;
                }
                routerNode.pop();
                return true;
              },
            ),
    );
  }

  void pushInitialRoutes(List<PageRouteInfo> routes) {
    if (!routerNode.stackIsEmpty) {
      return;
    }
    if (!listNullOrEmpty(routerNode.preMatchedRoutes)) {
      routerNode.pushAll(routerNode.preMatchedRoutes);
    } else if (!listNullOrEmpty(routes)) {
      routerNode.pushAll(routes);
    } else {
      var defaultConfig = routerNode.routeCollection.configWithPath('');
      if (defaultConfig != null) {
        if (defaultConfig.isRedirect) {
          routerNode.pushPath(defaultConfig.redirectTo);
        } else {
          routerNode.push(
            PageRouteInfo(
              defaultConfig.key,
              path: defaultConfig.path,
            ),
          );
        }
      }
    }
  }

  @override
  Future<void> setNewRoutePath(configuration) {
    assert(false);
    return SynchronousFuture(null);
  }
}

class DeclarativeRouterDelegate extends RouterDelegate
    with ChangeNotifier, PopNavigatorRouterDelegateMixin, StackedRouterDelegate {
  final RootRouterDelegate rootDelegate;
  final GlobalKey<NavigatorState> navigatorKey;
  final RouterNode routerNode;
  final Function(PageRouteInfo route) onPopRoute;
  final List<NavigatorObserver> navigatorObservers;

  DeclarativeRouterDelegate({
    this.rootDelegate,
    this.routerNode,
    this.navigatorObservers,
    @required this.onPopRoute,
    List<PageRouteInfo> routes,
  })  : assert(routerNode != null),
        navigatorKey = GlobalKey<NavigatorState>() {
    routerNode.addListener(() {
      notifyListeners();
      rootDelegate.notifyListeners();
    });
    updateRoutes(routes);
  }

  @override
  Widget build(BuildContext context) {
    return routerNode.stack.isEmpty
        ? Container(color: Colors.white)
        : Navigator(
            key: navigatorKey,
            pages: routerNode.stack,
            observers: navigatorObservers,
            onPopPage: (route, result) {
              if (!route.didPop(result)) {
                return false;
              }
              var data = (route.settings as StackedRoutePage).data;
              routerNode.pop();
              onPopRoute?.call(data.route);
              return true;
            },
          );
  }

  void updateRoutes(List<PageRouteInfo> routes) {
    if (!listNullOrEmpty(routes)) {
      routerNode.updateDeclarativeRoutes(routes, notify: false);
    }
  }

  @override
  Future<void> setNewRoutePath(configuration) {
    assert(false);
    return SynchronousFuture(null);
  }
}

//
//
// class ParallelRouterDelegate extends RouterDelegate with ChangeNotifier, AutoRouterDelegate {
//   final RootRouterDelegate rootDelegate;
//   List<PageRouteInfo> _parallelRoutes;
//   final RouterNode routerNode;
//   String _activeRouteKey;
//   final Function(String activeRoute) onActiveRouteChanged;
//
//   ParallelRouterDelegate({
//     @required this.rootDelegate,
//     @required this.routerNode,
//     @required List<PageRouteInfo> parallelRoutes,
//     @required String activeRouteKey,
//     this.onActiveRouteChanged,
//   })  : assert(routerNode != null),
//         assert(rootDelegate != null),
//         assert(activeRouteKey != null),
//         _activeRouteKey = activeRouteKey {
//     routerNode.addListener(() {
//       notifyListeners();
//       rootDelegate.notifyListeners();
//     });
//
//     setupRoutes(parallelRoutes);
//   }
//
//   void setupRoutes(List<PageRouteInfo> routes) {
//     List<PageRouteInfo> routesToPush = routes;
//     if (!listNullOrEmpty(routerNode.preMatchedRoutes)) {
//       for (var preMatchedRoute in routerNode.preMatchedRoutes) {
//         var route = routes.firstWhere(
//           (r) => r.path == preMatchedRoute.path,
//           orElse: () {
//             throw FlutterError('${preMatchedRoute.path} is not assign as a parallel route');
//           },
//         );
//         routesToPush.remove(route);
//       }
//       routesToPush.addAll(routerNode.preMatchedRoutes);
//       _activeRouteKey = routesToPush.last.path;
//       onActiveRouteChanged?.call(_activeRouteKey);
//     }
//     if (!listNullOrEmpty(routesToPush)) {
//       routerNode.replaceAll(routesToPush);
//     }
//     this._parallelRoutes = routesToPush;
//   }
//
//   void setActiveRoute(String activeRoute) {
//     _activeRouteKey = activeRoute;
//     onActiveRouteChanged?.call(_activeRouteKey);
//     // var data = parentNode.children.values
//     // 		.firstWhere((e) => e.key == activeRoute)
//     // 		.routeData;
//     // var key = ValueKey(data);
//     // var nodeToBringFront = parentNode.children[key];
//     // parentNode.children.remove(key);
//     // parentNode.children[key] = nodeToBringFront;
//     // WidgetsBinding.instance.addPostFrameCallback((_) {
//     //   rootDelegate.notifyListeners();
//     // });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     var keysList = _parallelRoutes.map((r) => r.path).toList(growable: false);
//     return routerNode.stack.isEmpty
//         ? Container()
//         : Stack(
//             fit: StackFit.expand,
//             children: List<Widget>.generate(keysList.length, (int index) {
//               final bool active = keysList[index] == _activeRouteKey;
//               var activePage = routerNode.stack.firstWhere((p) => p.data.key == keysList[index], orElse: () => null);
//               print(activePage);
//               return RouteDataProvider(
//                 data: activePage?.data,
//                 child: Offstage(
//                   offstage: !active,
//                   child: activePage?.child,
//                 ),
//               );
//             }),
//           );
//   }
//
//   @override
//   Future<bool> popRoute() {
//     var innerRouter = routerNode.findRouterOf(_activeRouteKey);
//     if (innerRouter == null) return SynchronousFuture<bool>(false);
//     return innerRouter.pop();
//   }
//
//   @override
//   Future<void> setNewRoutePath(configuration) {
//     assert(false);
//     return SynchronousFuture(null);
//   }
// }
//
// class RouteDataProvider extends InheritedWidget {
//   final RouteData data;
//
//   RouteDataProvider({this.data, Widget child}) : super(child: child);
//
//   @override
//   bool updateShouldNotify(covariant RouteDataProvider oldWidget) {
//     return data != oldWidget.data;
//   }
// }