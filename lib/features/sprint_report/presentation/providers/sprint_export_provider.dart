import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/export/sprint_exporter.dart';

part 'sprint_export_provider.g.dart';

@Riverpod(keepAlive: true)
SprintExporter sprintExporter(Ref ref) => const DefaultSprintExporter();
