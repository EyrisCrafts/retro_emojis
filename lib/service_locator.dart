import 'package:get_it/get_it.dart';
import 'package:retro_typer/services/service_local_storage.dart';

final getIt = GetIt.instance;

void setupServiceLocator() {
  GetIt.I.registerSingleton<ServiceLocalStorage>(ServiceLocalStorage());
}
