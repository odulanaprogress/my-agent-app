import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../../properties/models/task_model.dart';

class TaskProvider extends ChangeNotifier {
  List<TaskModel> tasks = [];

  TaskProvider() {
    loadTasks();
  }

  // LOAD
  Future<void> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('tasks');

    if (data != null) {
      final decoded = jsonDecode(data) as List;

      tasks = decoded
          .map(
            (e) => TaskModel.fromJson(
              e as Map<String, dynamic>,
              DateTime.now().millisecondsSinceEpoch.toString(),
            ),
          )
          .toList();
      notifyListeners();
    }
  }

  // SAVE
  Future<void> saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final data = tasks.map((e) => e.toJson()).toList();
    prefs.setString('tasks', jsonEncode(data));
  }

  // ADD
  void addTask(String title) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    tasks.insert(0, TaskModel(id: id, title: title, isDone: false));
    saveTasks();
    notifyListeners();
  }

  // DELETE
  void deleteTask(int index) {
    tasks.removeAt(index);
    saveTasks();
    notifyListeners();
  }

  // TOGGLE
  void toggleTask(int index) {
    final task = tasks[index];
    tasks[index] = TaskModel(
      id: task.id,
      title: task.title,
      isDone: !task.isDone,
    );
    saveTasks();
    notifyListeners();
  }
}
