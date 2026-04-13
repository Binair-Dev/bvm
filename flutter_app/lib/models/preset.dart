class Preset {
  final String id;
  final String name;
  final String description;
  final String category;
  final List<String> commands;
  final bool isBuiltIn;

  const Preset({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.commands,
    this.isBuiltIn = false,
  });

  factory Preset.fromJson(Map<String, dynamic> json) {
    return Preset(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      commands: List<String>.from(json['commands'] as List),
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'commands': commands,
      'isBuiltIn': isBuiltIn,
    };
  }

  Preset copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    List<String>? commands,
    bool? isBuiltIn,
  }) {
    return Preset(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      commands: commands ?? this.commands,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    );
  }

  // Built-in presets - only minimal Ubuntu
  static List<Preset> get builtIn => [
    const Preset(
      id: 'minimal',
      name: 'Minimal Ubuntu',
      description: 'Clean Ubuntu with only essential packages',
      category: 'base',
      commands: [
        'apt update',
        'apt install -y curl wget vim nano',
      ],
      isBuiltIn: true,
    ),
  ];
}
