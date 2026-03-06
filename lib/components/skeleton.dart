import 'package:flutter/material.dart';

class PaceSkeleton extends StatefulWidget {
  final double? height;
  final double? width;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const PaceSkeleton({
    super.key,
    this.height,
    this.width,
    this.borderRadius = 12,
    this.margin,
  });

  @override
  State<PaceSkeleton> createState() => _PaceSkeletonState();
}

class _PaceSkeletonState extends State<PaceSkeleton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.8).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        height: widget.height,
        width: widget.width,
        margin: widget.margin,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark 
              ? Colors.white.withOpacity(0.05) 
              : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      ),
    );
  }
}

class SkeletonGrid extends StatelessWidget {
  final int count;
  const SkeletonGrid({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      itemCount: count,
      itemBuilder: (_, __) => const PaceSkeleton(),
    );
  }
}

class SkeletonList extends StatelessWidget {
  final int count;
  const SkeletonList({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => Row(
        children: [
          const PaceSkeleton(width: 48, height: 48, borderRadius: 12),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PaceSkeleton(height: 16, width: 140),
                const SizedBox(height: 8),
                const PaceSkeleton(height: 12, width: 80),
              ],
            ),
          ),
          const PaceSkeleton(height: 24, width: 60, borderRadius: 6),
        ],
      ),
    );
  }
}
