import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/project_controller.dart';
import '../strings.dart';
import 'page_preview.dart';

/// Vertical strip of small page previews (the "PDF preview" side panel).
/// Clicking a page selects it in the main view.
class PageThumbnailStrip extends StatelessWidget {
  const PageThumbnailStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProjectController>();
    final imageCache = context.read<PreviewImageCache>();
    final plans = controller.plans;

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: SizedBox(
        width: 148,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                Strings.pages,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Expanded(
              child: plans.isEmpty
                  ? const SizedBox.shrink()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: plans.length,
                      itemBuilder: (context, index) {
                        final plan = plans[index];
                        final selected = index == controller.selectedPlanIndex;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: InkWell(
                            onTap: () => controller.selectPlan(index),
                            child: Column(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: selected
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : Colors.grey.shade400,
                                      width: selected ? 2 : 1,
                                    ),
                                  ),
                                  child: PagePreview(
                                    plan: plan,
                                    fitMode: controller.project.fitMode,
                                    imageCache: imageCache,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  plan.label,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
