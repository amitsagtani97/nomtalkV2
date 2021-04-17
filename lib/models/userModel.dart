class UserModel {
  final String name;
  final double points;
  final int level;
  final bool isSearching;
  final String subscription;
  final String mentorId;

  UserModel({
    this.name,
    this.points = 0.0,
    this.level = 1,
    this.isSearching = false,
    this.subscription = 'none',
    this.mentorId = '',
  });
}
