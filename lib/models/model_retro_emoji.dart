// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class ModelRetroEmoji {
  String shortName;
  String emoji;
  ModelRetroEmoji({
    required this.shortName,
    required this.emoji,
  });

  ModelRetroEmoji copyWith({
    String? shortName,
    String? emoji,
  }) {
    return ModelRetroEmoji(
      shortName: shortName ?? this.shortName,
      emoji: emoji ?? this.emoji,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'shortName': shortName,
      'emoji': emoji,
    };
  }

  factory ModelRetroEmoji.fromMap(Map<String, dynamic> map) {
    return ModelRetroEmoji(
      shortName: (map['shortcut'] ?? '') as String,
      emoji: (map['phrase'] ?? '') as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory ModelRetroEmoji.fromJson(String source) => ModelRetroEmoji.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() => 'ModelRetroEmoji(shortName: $shortName, emoji: $emoji)';

  @override
  bool operator ==(covariant ModelRetroEmoji other) {
    if (identical(this, other)) return true;

    return other.shortName == shortName && other.emoji == emoji;
  }

  @override
  int get hashCode => shortName.hashCode ^ emoji.hashCode;
}
