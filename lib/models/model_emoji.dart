// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:retro_typer/enums.dart';

class ModelEmoji {
  String emoji;
  String shortName;
  SearchType searchType;
  String memeUrl;

  ModelEmoji({
    this.emoji = "",
    this.shortName = "",
    this.searchType = SearchType.emojis,
    this.memeUrl = "",
  });
}
