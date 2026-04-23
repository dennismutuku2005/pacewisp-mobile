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

/// Mimics the Dashboard/Monthly Summary cards
class CardSkeleton extends StatelessWidget {
  final int count;
  const CardSkeleton({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => const PaceSkeleton(width: 140, height: 100, borderRadius: 24),
      ),
    );
  }
}

/// Mimics the Router/Mikrotik list tiles
class RouterSkeleton extends StatelessWidget {
  final int count;
  const RouterSkeleton({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, __) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            PaceSkeleton(width: 36, height: 36, borderRadius: 10),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PaceSkeleton(height: 12, width: 100),
                  SizedBox(height: 6),
                  PaceSkeleton(height: 8, width: 60),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                PaceSkeleton(height: 10, width: 30),
                SizedBox(height: 6),
                PaceSkeleton(height: 8, width: 40),
              ],
            ),
            SizedBox(width: 12),
            PaceSkeleton(width: 14, height: 14, borderRadius: 4),
          ],
        ),
      ),
    );
  }
}

/// Mimics Transaction/Entry/Voucher rows
class TransactionSkeleton extends StatelessWidget {
  final int count;
  const TransactionSkeleton({super.key, this.count = 8});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      separatorBuilder: (_, __) => const Divider(height: 32),
      itemBuilder: (_, __) => const Row(
        children: [
          PaceSkeleton(width: 40, height: 40, borderRadius: 20),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PaceSkeleton(height: 14, width: 120),
                SizedBox(height: 8),
                PaceSkeleton(height: 10, width: 80),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              PaceSkeleton(height: 14, width: 60),
              SizedBox(height: 8),
              PaceSkeleton(height: 10, width: 40),
            ],
          ),
        ],
      ),
    );
  }
}

/// Mimics Table rows (Monthly/Active customers)
class TableSkeleton extends StatelessWidget {
  final int count;
  const TableSkeleton({super.key, this.count = 10});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PaceSkeleton(height: 14, width: 110),
                  SizedBox(height: 6),
                  PaceSkeleton(height: 8, width: 60),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PaceSkeleton(height: 12, width: 50),
                  SizedBox(height: 6),
                  PaceSkeleton(height: 8, width: 40),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  PaceSkeleton(height: 20, width: 60, borderRadius: 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SkeletonList extends StatelessWidget {
  final int count;
  const SkeletonList({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return TransactionSkeleton(count: count);
  }
}
