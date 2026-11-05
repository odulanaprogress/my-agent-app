import 'package:cloud_firestore/cloud_firestore.dart';

enum CallStatus {
  calling,
  ringing,
  connected,
  ended,
  declined,
}

class CallModel {
  final String id;
  final String callerId;
  final String callerName;
  final String? callerPhoto;
  final String receiverId;
  final String receiverName;
  final String? receiverPhoto;
  final CallStatus status;
  final bool isVideo;
  final DateTime createdAt;
  final DateTime? connectedAt;
  final DateTime? endedAt;

  const CallModel({
    required this.id,
    required this.callerId,
    required this.callerName,
    this.callerPhoto,
    required this.receiverId,
    required this.receiverName,
    this.receiverPhoto,
    required this.status,
    this.isVideo = false,
    required this.createdAt,
    this.connectedAt,
    this.endedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'callerId': callerId,
      'callerName': callerName,
      'callerPhoto': callerPhoto,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverPhoto': receiverPhoto,
      'status': status.name,
      'isVideo': isVideo,
      'createdAt': Timestamp.fromDate(createdAt),
      'connectedAt': connectedAt != null ? Timestamp.fromDate(connectedAt!) : null,
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
    };
  }

  factory CallModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return CallModel(
      id: doc.id,
      callerId: data['callerId'] ?? '',
      callerName: data['callerName'] ?? 'User',
      callerPhoto: data['callerPhoto'],
      receiverId: data['receiverId'] ?? '',
      receiverName: data['receiverName'] ?? 'User',
      receiverPhoto: data['receiverPhoto'],
      status: _parseStatus(data['status']),
      isVideo: data['isVideo'] == true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      connectedAt: (data['connectedAt'] as Timestamp?)?.toDate(),
      endedAt: (data['endedAt'] as Timestamp?)?.toDate(),
    );
  }

  static CallStatus _parseStatus(String? str) {
    switch (str) {
      case 'ringing':
        return CallStatus.ringing;
      case 'connected':
        return CallStatus.connected;
      case 'ended':
        return CallStatus.ended;
      case 'declined':
        return CallStatus.declined;
      case 'calling':
      default:
        return CallStatus.calling;
    }
  }
}

