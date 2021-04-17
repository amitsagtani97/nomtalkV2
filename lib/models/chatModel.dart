class ChatModel {
  final String message;
  final String sentBy;
  final DateTime sentAt;

  ChatModel({this.message, this.sentBy, this.sentAt});

  Map<String, dynamic> toMap() {
    return {
      'message': this.message,
      'sentBy': this.sentBy,
      'sentAt': this.sentAt,
    };
  }
}
