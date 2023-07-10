import 'package:retro_typer/models/model_emoji.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ServiceLocalStorage {
  Future<void> saveEmojis(List<ModelEmoji> emoji) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setStringList("emojis", emoji.map((e) => e.toJson()).toList());
  }

  Future<List<ModelEmoji>> getEmojis() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final emojis = prefs.getStringList("emojis");
    if (emojis == null) {
      return [];
    }
    return emojis.map((e) => ModelEmoji.fromJson(e)).toList();
  }
}
