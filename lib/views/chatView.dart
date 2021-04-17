import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jitsi_meet/jitsi_meet.dart';
import 'package:talk_english/constants.dart';
import 'package:talk_english/models/chatModel.dart';
import 'package:jitsi_meet/jitsi_meeting_listener.dart';

class ChatView extends StatefulWidget {
  final String myId, othersId, roomId;
  const ChatView({Key key, this.myId, this.othersId, this.roomId}) : super(key: key);
  @override
  _ChatViewState createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  TextEditingController _textEditingController;
  final _firestore = Firestore.instance;

  @override
  void initState() {
    super.initState();
    _textEditingController = TextEditingController();
    JitsiMeet.addListener(JitsiMeetingListener(
      onConferenceWillJoin: _onConferenceWillJoin,
      onConferenceJoined: _onConferenceJoined,
      onConferenceTerminated: _onConferenceTerminated,
      onError: _onError,
    ));
  }

  @override
  void dispose() {
    super.dispose();
    _textEditingController.dispose();
    JitsiMeet.removeAllListeners();
  }

  _onConferenceWillJoin({message}) {
    debugPrint("_onConferenceWillJoin broadcasted");
  }

  _onConferenceJoined({message}) {
    debugPrint("_onConferenceJoined broadcasted");
  }

  _onConferenceTerminated({message}) {
    debugPrint("_onConferenceTerminated broadcasted");
  }

  _onError(error) {
    debugPrint("_onError broadcasted");
  }

  _joinMeeting() async {
    try {
      var options = JitsiMeetingOptions()
        ..room = widget.roomId // Required, spaces will be trimmed
        ..serverURL = null //	null for jitsi servers
        ..subject = "Time"
        ..userDisplayName = widget.myId
//        ..userEmail = "myemail@email.com"
        ..audioOnly = true
        ..audioMuted = false
        ..videoMuted = true;

      JitsiMeetingResponse response = await JitsiMeet.joinMeeting(
        options,
        listener: JitsiMeetingListener(onConferenceWillJoin: ({message}) {
          debugPrint("${options.room} will join with message: $message");
        }, onConferenceJoined: ({message}) {
          debugPrint("${options.room} joined with message: $message");
        }, onConferenceTerminated: ({message}) {
          debugPrint("${options.room} terminated with message: $message");
        }),
      );
      if (response.isSuccess == false) {
        debugPrint("ERROR: ${response.message}");
        // await updateStatus('isSearching');
      } else {
        debugPrint("SUCCESS: ${response.message}");
        // await updateStatus('isSearching');
      }
    } catch (error) {
      debugPrint("error: $error");
    }
  }

  Widget myMessage(BuildContext context, String text) {
    return Padding(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width / 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 1,
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.25,
            ),
          ),
          Flexible(
            flex: 3,
            child: Container(
              padding: EdgeInsets.all(MediaQuery.of(context).size.width / 48),
              decoration: BoxDecoration(
                color: gold,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
                border: Border.all(),
              ),
              child: Text(text),
            ),
          ),
        ],
      ),
    );
  }

  Widget othersMessage(BuildContext context, String text) {
    return Padding(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width / 48),
      child: Row(
        children: [
          Flexible(
            flex: 3,
            child: Container(
              padding: EdgeInsets.all(MediaQuery.of(context).size.width / 48),
              decoration: BoxDecoration(
                color: navy,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
                border: Border.all(),
              ),
              child: Text(
                text,
                style: TextStyle(color: white),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.25,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> sendMessage() async {
    ChatModel chat = ChatModel(message: formatMessage(), sentAt: DateTime.now(), sentBy: widget.myId);
    if (chat.message.isEmpty) return;
    FocusScope.of(context).unfocus();
    await _firestore.collection('chatrooms').document(widget.roomId).collection('chats').add(chat.toMap());
  }

  String formatMessage() {
    String message = _textEditingController.text.trim();
    _textEditingController.clear();
    return message;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: white,
            ),
            onPressed: () => Navigator.pop(context)),
        title: Text(' Chats ', style: head2),
        backgroundColor: black,
        actions: [
          RaisedButton(
            onPressed: () {
              _joinMeeting();
            },
            child: Image.asset(imgCall, height: 48, width: 48),
            color: black,
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            color: Colors.grey.withOpacity(0.5),
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('chatrooms').document(widget.roomId).collection('chats').orderBy('sentAt').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Text("[ERROR]: ${snapshot.error}");
                if (!snapshot.hasData) return Text('Loading...');
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: snapshot.data.documents.length,
                  itemBuilder: (context, i) {
                    ChatModel chat = ChatModel(
                      message: snapshot.data.documents.elementAt(i)['message'],
                      sentAt: snapshot.data.documents.elementAt(i)['sentAt'].toDate(),
                      sentBy: snapshot.data.documents.elementAt(i)['sentBy'],
                    );
                    return (chat.sentBy == widget.myId) ? myMessage(context, chat.message) : othersMessage(context, chat.message);
                  },
                );
              },
            ),
          ),
          Positioned(
            bottom: 0.0,
            left: 0.0,
            right: 0.0,
            child: TextField(
              controller: _textEditingController,
              decoration: InputDecoration(
                suffixIcon: IconButton(
                  icon: Icon(
                    Icons.send,
                  ),
                  onPressed: () {
                    sendMessage();
                  },
                ),
                fillColor: Colors.white,
                filled: true,
                border: OutlineInputBorder(),
                hintText: 'Type here ...',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
