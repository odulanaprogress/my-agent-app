import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/properties/models/task_model.dart';

class TaskService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  // Get current user ID
  String get userId => auth.currentUser!.uid;

  // 🔹 GET TASKS (REAL-TIME)
  Stream<List<TaskModel>> getTasks() {
    return firestore
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return TaskModel.fromJson(doc.data(), doc.id);
          }).toList();
        });
  }

  // 🔹 ADD TASK
  Future<void> addTask(String title) async {
    await firestore.collection('users').doc(userId).collection('tasks').add({
      'title': title,
      'isDone': false,
    });
  }

  // 🔹 TOGGLE TASK
  Future<void> toggleTask(TaskModel task) async {
    await firestore
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .doc(task.id)
        .update({'isDone': !task.isDone});
  }

  // 🔹 DELETE TASK
  Future<void> deleteTask(String id) async {
    await firestore
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .doc(id)
        .delete();
  }
}
