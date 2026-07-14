import 'package:flutter/material.dart';
import 'package:gihosync/constants/app_Colors.dart';

class MyContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final Color? bgColor;
  final EdgeInsetsGeometry? padding;
  final bool isPressed;

  const MyContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.bgColor,
    this.padding,
    this.isPressed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: Appcolors.secondary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isPressed
            ? [
                BoxShadow(
                  color: Appcolors.blurColor,
                  offset: Offset(2, 2),
                  blurRadius: 5,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Appcolors.blurColor,
                  offset: Offset(-2, -2),
                  blurRadius: 5,
                  spreadRadius: 1,
                ),
              ]
            : [
                BoxShadow(
                  color: Appcolors.blurColor,
                  offset: Offset(8, 8),
                  blurRadius: 15,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Appcolors.blurColor,
                  offset: Offset(-8, -8),
                  blurRadius: 15,
                  spreadRadius: 1,
                ),
              ],
      ),
      child: child,
    );
  }
}
