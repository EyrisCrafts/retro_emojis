// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:retro_typer/enums.dart';

class ModelEmoji {
  String emoji;
  String shortName;
  EnumSearchType searchType;
  String memeUrl;

  ModelEmoji({
    this.emoji = "",
    this.shortName = "",
    this.searchType = EnumSearchType.emojis,
    this.memeUrl = "",
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'emoji': emoji,
      'shortName': shortName,
      'searchType': searchType.name,
      'memeUrl': memeUrl,
    };
  }

  factory ModelEmoji.fromMap(Map<String, dynamic> map) {
    return ModelEmoji(
      emoji: (map['emoji'] ?? '') as String,
      shortName: (map['shortName'] ?? '') as String,
      searchType: EnumSearchType.values.firstWhere((element) => element.name == (map['searchType'] ?? '') as String),
      memeUrl: (map['memeUrl'] ?? '') as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory ModelEmoji.fromJson(String source) => ModelEmoji.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  bool operator ==(covariant ModelEmoji other) {
    if (identical(this, other)) return true;

    return other.emoji == emoji && other.shortName == shortName && other.searchType == searchType && other.memeUrl == memeUrl;
  }

  @override
  int get hashCode {
    return emoji.hashCode ^ shortName.hashCode ^ searchType.hashCode ^ memeUrl.hashCode;
  }
}
