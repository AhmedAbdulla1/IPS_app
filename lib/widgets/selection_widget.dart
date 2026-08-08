import 'package:pathfinder/controllers/beacon_controller.dart';
import 'package:pathfinder/controllers/navigation_controller.dart';
import 'package:pathfinder/models/location.dart';
import 'package:pathfinder/utils/constants.dart';
import 'package:pathfinder/utils/size_config.dart';
import 'package:pathfinder/utils/size_helpers.dart';
import 'package:pathfinder/views/navigation_page.dart';
import 'package:pathfinder/views/settings_page.dart';
import 'package:pathfinder/widgets/rounded_button.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dropdown_search/dropdown_search.dart';


class SelectionWidget extends StatelessWidget {
  final beaconController = Get.find<BeaconController>();
  final navigationController = Get.find<NavigationController>();
  final _ddKey = GlobalKey<DropdownSearchState<LocationInfo>>();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: UniqueKey(),
      child: SafeArea(
        child: SizedBox(
          child: Column(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: displayHeight(context) * 0.03,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.settings_outlined,
                            color: kSecondaryColor,
                            size: displayWidth(context) * 0.08,
                          ),
                          onPressed: () {
                            Get.to(SettingsPage());
                            // Get.defaultDialog(
                            //   title: 'Beacon List',
                            //   content: Obx(
                            //     () => Text(beaconController.printList),
                            //   ),
                            // );
                          },
                        ),
                                              ],
                    ),
                    SizedBox(
                      height: displayHeight(context) * 0.03,
                    ),
                    Text(
                      'Current Location:',
                      style: TextStyle(
                        fontSize: getDefaultProportionateScreenWidth(),
                      ),
                    ),
                    SizedBox(
                      height: displayHeight(context) * 0.03,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Section: ',
                              style: TextStyle(
                                fontSize: getProportionateScreenWidth(18),
                              ),
                            ),
                            Text(
                              beaconController.currentLocation.value.section,
                              style: TextStyle(
                                color: kPrimaryColor,
                                fontSize: getProportionateScreenWidth(18),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              'Level: ',
                              style: TextStyle(
                                fontSize: getProportionateScreenWidth(18),
                              ),
                            ),
                            Text(
                              beaconController.currentLocation.value.level == 0
                                  ? 'B1'
                                  : beaconController.currentLocation.value.level
                                      .toString(),
                              style: TextStyle(
                                color: kPrimaryColor,
                                fontSize: getProportionateScreenWidth(18),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Spacer(),
                    Container(
                      height: getProportionateScreenHeight(130),
                      child: Obx(
                        () => AnimatedSwitcher(
                          duration: Duration(milliseconds: 2000),
                          transitionBuilder: (widget, animation) {
                            final offsetAnimation = Tween<Offset>(
                              begin: const Offset(1.5, 0.0),
                              end: Offset.zero,
                            ).animate(animation);
                            return SlideTransition(
                              position: offsetAnimation,
                              child: widget,
                            );
                          },
                          switchOutCurve: Curves.elasticOut,
                          switchInCurve: Curves.elasticIn,
                          child: Container(
                            key: UniqueKey(),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  beaconController.currentLocation.value.name,
                                  key: UniqueKey(),
                                  style: TextStyle(
                                    fontSize: getProportionateScreenWidth(36),
                                    color: kPrimaryColor,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                Image.asset(
                                  'assets/images/vectors/vector_shadow.png',
                                  width: displayWidth(context) * 0.8,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Spacer(),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    // Obx(
                    //   () =>
                    DropdownSearch<LocationInfo>(
                      key: _ddKey,
                      compareFn: (item, selectedItem) =>
                          item.nodeID == selectedItem.nodeID,
                      itemAsString: (LocationInfo loc) => loc.name,
                      decoratorProps: DropDownDecoratorProps(
                        decoration: InputDecoration(
                          labelText: 'Select Destination',
                        ),
                      ),
                      popupProps: PopupProps.bottomSheet(
                        showSearchBox: true,
                        searchFieldProps: TextFieldProps(
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            labelText: 'Search Point of Interests',
                          ),
                        ),
                      ),
                      items: (String filter, dynamic infiniteScrollProps) =>
                          beaconController.onSearch(filter),

                      onSelected: (value) {
                        if (value != null) {
                          beaconController.setDestination(value.nodeID);
                          print(beaconController.destinationLocation?.name);
                        }
                      },
                    ),
                    // ),
                    SizedBox(
                      height: displayHeight(context) * 0.02,
                    ),
                    RoundedButton(
                      btnText: 'Continue',
                      btnColor: kPrimaryColor,
                      btnFunction: () {
                        final destination = beaconController.destinationLocation;
                        if (destination == null) {
                          Get.rawSnackbar(
                            titleText: Text(
                              'Error',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            messageText: Text(
                              'Please select a destination',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          );
                        } else {
                          navigationController.setNavigationSettings(
                            beaconController.poiNodes,
                            beaconController.poiList,
                            beaconController.currentLocation.value.nodeID,
                            destination.nodeID,
                          );
                          navigationController.findPathToDestination();
                          navigationController.isNavigating = true;
                          beaconController.destinationLocation = null;
                          _ddKey.currentState?.changeSelectedItem(null);
                          Get.to(NavigationPage());
                        }
                      },
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
