import '../core/utils/app_logger.dart';
import 'dart:math';

import 'package:pathfinder/models/neighbour_node.dart';
import 'package:pathfinder/models/poinode.dart';
import 'package:pathfinder/utils/constants.dart';
import 'package:get/get.dart';

class NavigationController extends GetxController {
  late Map<int, POINode> nodesHashMap;
  List<POINode> poiPriorityQueue = [];
  List<POINode> expandedNodes = [];
  Comparator<POINode> heuristicComparator =
      (a, b) => a.fValue.compareTo(b.fValue);

  late int startingNodeId;
  late int destinationNodeId;
  List<NeighbourNode> pathArray = <NeighbourNode>[];
  final directionDegree = 0.0.obs;
  final reachedDestination = false.obs;
  final pathArrayLength = 'Loading...'.obs;
  // final beaconController = Get.find<BeaconController>();
  // final beaconList = <BeaconData>[].obs;
  bool isNavigating = false;
  // Reactive mirror of [isNavigating]. `isNavigating` predates this
  // controller's GetX adoption and several older widgets (NavigationPage,
  // SelectionWidget) already read/write it directly as a plain bool, so it
  // is kept as-is to avoid touching that code. HomePage needs to *react*
  // to navigation starting/stopping (to switch between the "pick a
  // destination" and "follow the arrow" sections), which a plain bool
  // can't do inside an Obx -- hence this Rx counterpart, kept in sync
  // wherever isNavigating changes.
  final isNavigatingRx = false.obs;
  var tempDistanceTo = 0.0;
  final levelNavigation = LevelNavigation.empty.obs;
  final currentNode = POINode(
    level: 0,
    name: '',
    nearestLift: 0,
    neighbourArray: [],
    nodeESP32ID: '',
    nodeID: 0,
    nodeName: '',
    poiType: POIType.poi,
    section: '',
    x: 0,
    y: 0,
  ).obs;
  void setNavigationSettings(
    Map<int, POINode> hashMap,
    List<POINode> priorityQueue,
    int currentId,
    int destinationId,
  ) {
    AppLogger.debug("Setting Navigation Settings");
    reachedDestination.value = false;
    nodesHashMap = {...hashMap};
    poiPriorityQueue = [...priorityQueue];
    startingNodeId = currentId;
    destinationNodeId = destinationId;
  }

  /// Starts a navigation session: stores the requested destination and
  /// flips both the plain-bool and reactive "is navigating" flags together
  /// so nothing can read one without the other.
  void startNavigation(
    Map<int, POINode> hashMap,
    List<POINode> priorityQueue,
    int currentId,
    int destinationId,
  ) {
    setNavigationSettings(hashMap, priorityQueue, currentId, destinationId);
    findPathToDestination();
    isNavigating = true;
    isNavigatingRx.value = true;
  }

  /// Cancels the current navigation session and resets everything back to
  /// the idle state HomePage's "pick a destination" section expects.
  void cancelNavigation() {
    isNavigating = false;
    isNavigatingRx.value = false;
    reachedDestination.value = false;
    levelNavigation.value = LevelNavigation.empty;
    pathArray.clear();
    pathArrayLength.value = 'Loading...';
  }

  void printList() {
    AppLogger.debug("Current Node: ${currentNode.value.nodeID}");
    var tempString = "";
    pathArray.forEach((element) {
      tempString +=
          "${element.nodeID} : ${element.heading} : ${element.levelNavigation} \n";
    });
    AppLogger.debug(tempString);
  }

  String get directionString {
    return 'Walk towards ${directionDegree.value}';
  }

  void setCurrentLocation(POINode node) {
    currentNode.value = node;
    if (isNavigating) {
      if (pathArray.isNotEmpty) {
        AppLogger.debug('List Length: ${pathArray.length}');
        AppLogger.debug(pathArray.toString());
        if (pathArray.first.nodeID == node.nodeID) {
          if (pathArray.length != 1) {
            pathArray.removeAt(0);
            switch (pathArray.first.levelNavigation) {
              case LevelNavigation.go_down:
                levelNavigation.value = LevelNavigation.go_down;
                break;
              case LevelNavigation.go_up:
                levelNavigation.value = LevelNavigation.go_up;
                break;
              default:
                if (levelNavigation.value != LevelNavigation.same_level) {
                  levelNavigation.value = LevelNavigation.same_level;
                }
                break;
            }

            directionDegree.value = pathArray.first.heading;
          } else {
            pathArray.removeAt(0);
            isNavigating = false;
            isNavigatingRx.value = false;
            AppLogger.debug("Reached Destination");
            reachedDestination.value = true;
            levelNavigation.value = LevelNavigation.reach_destination;
          }
        }

        pathArrayLength.value = pathArray.length.toString();
      }
    }
  }

  double getHeuristic(double x1, double x2, double y1, double y2) {
    return sqrt(pow((x2 - x1), 2) + pow((y2 - y1), 2));
  }

  Future<void> findPathToDestination() async {
    for (var i = 1; i <= poiPriorityQueue.length; i++) {
      nodesHashMap[i]!.fValue = 9999999;
      nodesHashMap[i]!.heuristic = 9999999;
      nodesHashMap[i]!.from = null;
      nodesHashMap[i]!.distanceTo = 0;

      poiPriorityQueue[i - 1].fValue = 9999999;
      poiPriorityQueue[i - 1].heuristic = 9999999;
      poiPriorityQueue[i - 1].from = null;
      poiPriorityQueue[i - 1].distanceTo = 0;
    }

    var currentNode = nodesHashMap[startingNodeId]!;
    var destinationNode = nodesHashMap[destinationNodeId]!;
    var sameLevel = true;
    var reachedLift = false;
    POINode? nextLevelDestinationNode;

    if (currentNode.level != destinationNode.level) {
      sameLevel = false;
      nextLevelDestinationNode = destinationNode;
      destinationNode = nodesHashMap[currentNode.nearestLift]!;
    }
    if (currentNode.nodeID == destinationNode.nodeID) {
      reachedLift = true;
    }

    pathArray.clear();
    expandedNodes.clear();
    int count = 0;
    while (currentNode.nodeID != destinationNode.nodeID || reachedLift) {
      AppLogger.debug("Counting: ${count++}");
      if (!sameLevel && reachedLift) {
        reachedLift = false;
        sameLevel = true;
        destinationNode = nextLevelDestinationNode!;

        POINode neighbourPOI = poiPriorityQueue.firstWhere(
            (element) => element.nodeID == currentNode.nextLevelLift);
        neighbourPOI.from = currentNode.nodeID;

        expandedNodes.add(poiPriorityQueue
            .firstWhere((element) => element.nodeID == currentNode.nodeID));
        poiPriorityQueue
            .removeWhere((element) => element.nodeID == currentNode.nodeID);
        currentNode = poiPriorityQueue
            .firstWhere((element) => element.nodeID == neighbourPOI.nodeID);
      } else {
        AppLogger.debug('Neighbour Array: ${currentNode.neighbourArray}');
        for (NeighbourNode neighbour in currentNode.neighbourArray) {
          var index = expandedNodes
              .indexWhere((element) => element.nodeID == neighbour.nodeID);
          if (index == -1) {
            POINode neighbourPOI = poiPriorityQueue
                .firstWhere((element) => element.nodeID == neighbour.nodeID);

            neighbourPOI.heuristic = getHeuristic(destinationNode.x,
                neighbourPOI.x, destinationNode.y, neighbourPOI.y);

            tempDistanceTo = currentNode.distanceTo + neighbour.distanceTo;
            if (neighbourPOI.distanceTo > tempDistanceTo ||
                neighbourPOI.distanceTo == 0) {
              neighbourPOI.distanceTo = tempDistanceTo;
              neighbourPOI.from = currentNode.nodeID;
            }

            neighbourPOI.fValue =
                neighbourPOI.distanceTo + neighbourPOI.heuristic;
          }
        }
        expandedNodes.add(poiPriorityQueue
            .firstWhere((element) => element.nodeID == currentNode.nodeID));
        poiPriorityQueue
            .removeWhere((element) => element.nodeID == currentNode.nodeID);
        poiPriorityQueue.sort(heuristicComparator);
        AppLogger.debug('Queue: ${poiPriorityQueue.toString()}');
        currentNode = poiPriorityQueue.first;
        if (currentNode.nodeID == currentNode.nearestLift && !sameLevel) {
          reachedLift = true;
        }
      }
    }
    //Reached Destination, Add to expandedNodes
    expandedNodes.add(poiPriorityQueue
        .firstWhere((element) => element.nodeID == destinationNodeId));
    var retraceNode = expandedNodes
        .firstWhere((element) => element.nodeID == destinationNodeId);

    while (retraceNode.nodeID != startingNodeId) {
      var neighbourNode = nodesHashMap[retraceNode.from]!
          .neighbourArray
          .firstWhere((element) => element.nodeID == retraceNode.nodeID);
      pathArray.add(neighbourNode);
      retraceNode = nodesHashMap[retraceNode.from]!;
    }

    pathArray.add(NeighbourNode(nodeID: startingNodeId));

    pathArray = pathArray.reversed.toList();
    AppLogger.debug('Path: ${pathArray.toString()}');
  }
}
