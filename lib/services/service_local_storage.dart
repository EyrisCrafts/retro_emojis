import 'package:retro_typer/enums.dart';
import 'package:retro_typer/models/model_emoji.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ServiceLocalStorage {
  Future<void> saveEmojis(List<ModelEmoji> emoji) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setStringList("emojis", emoji.take(25).map((e) => e.toJson()).toList());
  }

  Future<List<ModelEmoji>> getEmojis() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final emojis = prefs.getStringList("emojis");
    if (emojis == null) {
      return [];
    }
    return emojis.map((e) => ModelEmoji.fromJson(e)).toList();
  }

  Future<void> saveEnabledTypes(List<String> enabledTypes) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setStringList("enabledTypes", enabledTypes);
  }

  Future<List<String>> getEnabledTypes() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final enabledTypes = prefs.getStringList("enabledTypes");
    if (enabledTypes == null) {
      return EnumSearchType.values.map((e) => e.name).toList();
    }
    return enabledTypes;
  }

  Future<void> saveGridCrossAxisCount(int gridCrossAxisCount) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setInt("gridCrossAxisCount", gridCrossAxisCount);
  }

  Future<int> getGridCrossAxisCount() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final gridCrossAxisCount = prefs.getInt("gridCrossAxisCount");
    if (gridCrossAxisCount == null) {
      return 3;
    }
    return gridCrossAxisCount;
  }

  Future<void> saveMaxMemesLoad(int maxMemesLoad) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setInt("maxMemesLoad", maxMemesLoad);
  }

  Future<int> getMaxMemesLoad() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final maxMemesLoad = prefs.getInt("maxMemesLoad");
    if (maxMemesLoad == null) {
      return 20;
    }
    return maxMemesLoad;
  }
}
