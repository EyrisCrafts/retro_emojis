import 'package:get_it/get_it.dart';
import 'package:retro_typer/enums.dart';
import 'package:retro_typer/services/service_local_storage.dart';
import 'package:retro_typer/services/service_user_preferences.dart';

final getIt = GetIt.instance;

void setupServiceLocator() {
  GetIt.I.registerSingleton<ServiceLocalStorage>(ServiceLocalStorage());
  GetIt.I.registerSingleton<ServiceUserPreferences>(
      ServiceUserPreferences(gridCrossAxisCount: 3, maxMemesLoad: 10, enabledTypes: [EnumSearchType.emojis, EnumSearchType.gif, EnumSearchType.ascii, EnumSearchType.image]));
}
