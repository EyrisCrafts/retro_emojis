// ignore_for_file: public_member_api_docs, sort_constructors_first

import 'package:get_it/get_it.dart';
import 'package:retro_typer/enums.dart';
import 'package:retro_typer/services/service_local_storage.dart';

class ServiceUserPreferences {
  int gridCrossAxisCount;
  int maxMemesLoad;
  List<EnumSearchType> enabledTypes;

  ServiceUserPreferences({
    required this.gridCrossAxisCount,
    required this.maxMemesLoad,
    required this.enabledTypes,
  });

  // Load from shared preferences

  Future<void> init() async {
    // Load from shared preferences
    gridCrossAxisCount = await GetIt.I<ServiceLocalStorage>().getGridCrossAxisCount();

    maxMemesLoad = await GetIt.I<ServiceLocalStorage>().getMaxMemesLoad();

    enabledTypes = (await GetIt.I<ServiceLocalStorage>().getEnabledTypes()).map((e) => EnumSearchType.values.firstWhere((element) => element.name == e)).toList();
  }
}
