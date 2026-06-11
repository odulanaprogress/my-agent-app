class TaskModel {
  final String id;
  final String title;
  final bool isDone;

  TaskModel({required this.id, required this.title, required this.isDone});

  // Convert Firestore → TaskModel
  factory TaskModel.fromJson(Map<String, dynamic> json, String id) {
    return TaskModel(
      id: id,
      title: json['title'] ?? '',
      isDone: json['isDone'] ?? false,
    );
  }

  // Convert TaskModel → Firestore
  Map<String, dynamic> toJson() {
    return {'title': title, 'isDone': isDone};
  }
}
