import '../models/project.dart';
import 'freeform_layout.dart';
import 'grid_layout.dart';
import 'page_plan.dart';

export 'freeform_layout.dart';
export 'grid_layout.dart';
export 'mirror.dart';
export 'natural_sort.dart';
export 'page_plan.dart';

/// Lays out a project according to its mode.
List<PagePlan> planProject(PnpProject project) => switch (project.mode) {
      ProjectMode.grid => planGrid(project),
      ProjectMode.freeform => planFreeform(project),
    };
