import 'package:flutter/material.dart';
import 'package:agent_app/core/widgets/app_loader.dart';


class LoadingWidget extends StatelessWidget {
  final String? text;

  const LoadingWidget({super.key, this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppLoader(size: 24),
          if (text != null) ...[const SizedBox(height: 12), Text(text!)],
        ],
      ),
    );
  }
}
