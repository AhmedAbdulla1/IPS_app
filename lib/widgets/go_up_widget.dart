import 'package:pathfinder/utils/size_config.dart';
import 'package:pathfinder/utils/size_helpers.dart';
import 'package:flutter/material.dart';

class GoUpWidget extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment(0, 0),
      key: UniqueKey(),
      child: Column(
        children: [
          Image.asset(
            'assets/images/elevator_up.gif',
            height: displayHeight(context) * 0.4,
          ),
          SizedBox(
            height: displayHeight(context) * 0.02,
          ),
          Text(
            'Go Up One Level',
            style: TextStyle(
              fontSize: getDefaultProportionateScreenWidth(),
            ),
          ),
        ],
      ),
    );
  }
}
