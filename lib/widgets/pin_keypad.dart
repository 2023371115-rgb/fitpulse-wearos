import 'package:flutter/material.dart';

class PinDots extends StatelessWidget {
  final int length;
  final int total;

  const PinDots({
    super.key,
    required this.length,
    this.total = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (index) {
        final filled = index < length;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          width: filled ? 8 : 7,
          height: filled ? 8 : 7,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: filled ? const Color(0xFF0F9D58) : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: filled ? const Color(0xFF0F9D58) : Colors.white38,
              width: 1.2,
            ),
          ),
        );
      }),
    );
  }
}

class NumericKeypad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final bool disabled;
  final double scale;

  const NumericKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.disabled = false,
    this.scale = 1,
  });

  @override
  Widget build(BuildContext context) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'back'];

    return LayoutBuilder(
      builder: (context, constraints) {
        final shortestSide = constraints.biggest.shortestSide;
        final buttonSize = ((shortestSide / 4.45) * scale).clamp(30.0, 42.0).toDouble();
        final gap = (buttonSize * 0.12).clamp(3.0, 5.0).toDouble();

        return Center(
          child: SizedBox(
            width: (buttonSize * 3) + (gap * 2),
            height: (buttonSize * 4) + (gap * 3),
            child: GridView.builder(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: keys.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: gap,
                crossAxisSpacing: gap,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                final key = keys[index];
                if (key.isEmpty) return const SizedBox.shrink();

                if (key == 'back') {
                  return _KeypadButton(
                    enabled: !disabled,
                    onTap: onBackspace,
                    child: const Icon(Icons.backspace_outlined, color: Colors.white70, size: 18),
                  );
                }

                return _KeypadButton(
                  enabled: !disabled,
                  onTap: () => onDigit(key),
                  child: Text(
                    key,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _KeypadButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool enabled;

  const _KeypadButton({
    required this.child,
    required this.onTap,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: enabled ? 0.10 : 0.04),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: const CircleBorder(),
        splashColor: const Color(0xFF0F9D58).withValues(alpha: 0.25),
        highlightColor: Colors.white.withValues(alpha: 0.08),
        child: Center(child: child),
      ),
    );
  }
}
