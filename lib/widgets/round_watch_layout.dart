import 'dart:math' as math;

import 'package:flutter/material.dart';

class RoundWatchLayout extends StatelessWidget {
  final Widget child;
  final double paddingFactor;

  const RoundWatchLayout({
    super.key,
    required this.child,
    this.paddingFactor = 0.09,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = math.min(constraints.maxWidth, constraints.maxHeight);
          final padding = side * paddingFactor;

          return Center(
            child: SizedBox.square(
              dimension: side,
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}
