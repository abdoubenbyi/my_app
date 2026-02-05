class CheatSheet {
  final String id;
  final String title;
  final List<String> tags;
  final String intro;
  final String content;
  final String? backgroundHex;
  final String iconPath;

  CheatSheet({
    required this.id,
    required this.title,
    required this.tags,
    required this.intro,
    required this.content,
    this.backgroundHex,
    required this.iconPath,
  });
}
