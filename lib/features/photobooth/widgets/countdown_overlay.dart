import 'package:flutter/material.dart';

class CountdownOverlay extends StatelessWidget {
  final int value;

  const CountdownOverlay({
    super.key,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    if (value <= 0) {
      return const SizedBox.shrink();
    }

    return Center(
      child: AnimatedSwitcher(
        duration: const Duration(
          milliseconds: 250,
        ),
        child: Text(
          '$value',
          key: ValueKey(value),
          style: const TextStyle(
            fontSize: 130,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            shadows: [
              Shadow(
                blurRadius: 25,
                color: Colors.black87,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
