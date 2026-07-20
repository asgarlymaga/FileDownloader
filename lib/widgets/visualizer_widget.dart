import 'package:flutter/material.dart';

class VisualizerWidget extends StatelessWidget {
  final Stream<List<double>> visualizerStream;
  final bool isPlaying;

  const VisualizerWidget({
    super.key,
    required this.visualizerStream,
    required this.isPlaying,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.15),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: StreamBuilder<List<double>>(
        stream: visualizerStream,
        builder: (context, snapshot) {
          final wave = snapshot.data ?? List.filled(20, 0.05);
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(wave.length, (index) {
              double val = wave[index];
              if (!isPlaying) {
                val = 0.05;
              }
              // Smooth values
              final double height = (val * 90).clamp(6, 96);
              return AnimatedContainer(
                duration: const Duration(milliseconds: 70),
                width: 6,
                height: height,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isPlaying
                        ? [
                            Theme.of(context).primaryColor,
                            Theme.of(context).colorScheme.secondary,
                          ]
                        : [
                            Colors.grey.shade400,
                            Colors.grey.shade500,
                          ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
