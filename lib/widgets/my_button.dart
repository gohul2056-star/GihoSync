import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:gihosync/constants/app_Colors.dart';

class MyButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPress;
  final EdgeInsetsGeometry? padding;
  final bool isPressed;
  final Color btnBackGround;
  final Color blurFirstColor;
  final Color blurSecondColor;

  const MyButton({
    super.key,
    required this.child,
    required this.onPress,
    this.padding,
    this.isPressed = false,
    this.blurFirstColor = Appcolors.blurColor,
    this.blurSecondColor = Colors.white10,
    this.btnBackGround = const Color(0xFF1A0533),
  });

  @override
  State<MyButton> createState() => _MyButtonState();
}

class _MyButtonState extends State<MyButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 0.08,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double basePadding = MediaQuery.of(context).size.width * 0.03;
    final bool isAccent = widget.btnBackGround == Appcolors.primary ||
        widget.btnBackGround == Appcolors.accent;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onPress();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          padding: widget.padding ?? EdgeInsets.all(basePadding),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isAccent
                ? const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isAccent ? null : Colors.white.withValues(alpha: 0.1),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: isAccent
                ? [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: ClipOval(
            child: BackdropFilter(
              filter: isAccent
                  ? ImageFilter.blur(sigmaX: 0, sigmaY: 0)
                  : ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Center(child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}
