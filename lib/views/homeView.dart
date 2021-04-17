import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:jitsi_meet/jitsi_meet.dart';
import 'package:jitsi_meet/jitsi_meeting_listener.dart';
import 'package:smooth_star_rating/smooth_star_rating.dart';
import 'package:talk_english/models/mentorModel.dart';
import 'package:talk_english/models/userModel.dart';
import 'package:talk_english/views/chatView.dart';

import '../constants.dart';

class HomeView extends StatefulWidget {
  @override
  _HomeViewState createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final _auth = FirebaseAuth.instance;
  final _firestore = Firestore.instance;
  final _googleSignIn = GoogleSignIn();
  bool _googleSignedIn = false, isLoading = false, isMentor = false;
  UserModel currUser;
  MentorModel currMentor;
  String docId = "";

  Future<DocumentSnapshot> initialFuture;

  static const String testID = 'testsubscription';
  bool _available = true;
  InAppPurchaseConnection _iap = InAppPurchaseConnection.instance;
  List<ProductDetails> _products = [];
  List<PurchaseDetails> _purchases = [];
  StreamSubscription _subscription;

  @override
  void initState() {
    super.initState();
    JitsiMeet.addListener(JitsiMeetingListener(
      onConferenceWillJoin: _onConferenceWillJoin,
      onConferenceJoined: _onConferenceJoined,
      onConferenceTerminated: _onConferenceTerminated,
      onError: _onError,
    ));
    initialFuture = initFuture();
    _initializeIAP();
  }

  void _initializeIAP() async {
    _available = await _iap.isAvailable();
    if (_available) {
      await _getProducts();
      await _getPastPurchases();
      _verifyPurchase();

      //listen to new purchases
      _iap.purchaseUpdatedStream.listen((data) {
        setState(() {
          print('Buy button tapped: $data');
          _purchases.addAll(data);
          _verifyPurchase();
        });
      });
    } else
      print('Not Available');
  }

  Future<void> _getProducts() async {
    Set<String> ids = Set.from([testID]);
    ProductDetailsResponse response = await _iap.queryProductDetails(ids);
    if (response.notFoundIDs.isNotEmpty) {
      print('[ERROR1]: ${response.error}');
    }
    setState(() {
      _products = response.productDetails;
    });
  }

  Future<void> _getPastPurchases() async {
    QueryPurchaseDetailsResponse response = await _iap.queryPastPurchases();
    if (response.error != null) {
      print('[ERROR2]: ${response.error}');
    }
    for (PurchaseDetails purchase in response.pastPurchases) {
      final pending = Platform.isIOS ? purchase.pendingCompletePurchase : !purchase.billingClientPurchase.isAcknowledged;

      if (pending) {
        InAppPurchaseConnection.instance.completePurchase(purchase);
      }
    }
    //TODO: query Firebase for details
    setState(() {
      _purchases = response.pastPurchases;
    });
  }

  PurchaseDetails _hasPurchased(String productID) {
    return _purchases.firstWhere((element) => element.productID == productID, orElse: () => null);
  }

  void _verifyPurchase() {
    PurchaseDetails purchase = _hasPurchased(testID);
    //TODO: from firebase check  and record subscription
    if (purchase != null && purchase.status == PurchaseStatus.purchased) {
      //TODO: change currUser.subscription=DateOfPurchase+30 in DateTime. change required;
    }
  }

  void _buyProduct(ProductDetails prod) {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: prod);
    _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  @override
  void dispose() {
    super.dispose();
    _subscription.cancel();
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

  Future<void> _logout() async {
    try {
      await _auth.signOut();
      if (_googleSignedIn) {
        await _googleSignIn.signOut();
      }
    } catch (e) {
      print(e.toString());
    }
  }

  Future<DocumentSnapshot> initFuture() async {
    //get docId of current user
    FirebaseUser user = await _auth.currentUser();
    docId = user.uid;
    //check if this user is mentor
    await _firestore.collection('mentors').document(docId).get().then((snapshot) {
      if (snapshot.exists) isMentor = true;
    });
    //check for google sign in
    _googleSignedIn = await _googleSignIn.isSignedIn();
    //get user data
    return (isMentor)
        ? await _firestore.collection('mentors').document(docId).get()
        : await _firestore.collection('users').document(docId).get();
  }

  void getDocId() {
    _auth.onAuthStateChanged.firstWhere((user) => user != null).then((user) {
      docId = user.uid;
      print(docId);
    });
  }

  _joinMeeting(String roomName) async {
    try {
      var options = JitsiMeetingOptions()
        ..room = roomName // Required, spaces will be trimmed
        ..serverURL = null //	null for jitsi servers
        ..subject = "Time"
        ..userDisplayName = currUser.name
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
          Future.delayed(Duration(milliseconds: 1500)).then((value) => ratingDialog(context));
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

  callRandomDialog(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Searching...'),
          content: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Finding users online. Please wait!'),
          ),
          contentPadding: EdgeInsets.all(10.0),
          actions: <Widget>[
            FlatButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                setState(() {
                  isLoading = true;
                });
                await removeUser();
                setState(() {
                  isLoading = false;
                });
              },
              icon: Icon(
                Icons.call_end,
                color: Colors.red,
              ),
              label: Text(
                'Go Back',
              ),
            ),
          ],
        );
      },
    );
  }

  double rating = 3.0;

  ratingDialog(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Give Rating'),
          content: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Rate your experience talking with this user!'),
                SmoothStarRating(
                  allowHalfRating: false,
                  onRated: (v) {
                    rating = v;
                  },
                  starCount: 5,
                  rating: rating,
                  size: 40,
                  filledIconData: Icons.star,
                  halfFilledIconData: Icons.star_border,
                  color: gold,
                  borderColor: gold,
                  spacing: 0,
                ),
              ],
            ),
          ),
          contentPadding: EdgeInsets.all(10.0),
          actions: <Widget>[
            FlatButton(
              onPressed: () {
                Navigator.of(context).pop();
                updatePoints();
              },
              child: Text(
                'Rate',
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> updatePoints() async {
    double currPoints = currUser.points;
    double newPoints = currPoints + rating;
    int newLevel = 1;
    if (newPoints > 500) {
      newLevel = 5;
    } else if (newPoints > 300) {
      newLevel = 4;
    } else if (newPoints > 150) {
      newLevel = 3;
    } else if (newPoints > 100) {
      newLevel = 2;
    }
    await _firestore.collection('users').document(docId).updateData({
      'points': newPoints,
      'level': newLevel,
    });
  }

  Future<void> updateStatus(String val) async {
    DocumentReference docRef = _firestore.collection('users').document(docId);
    return _firestore
        .runTransaction((transaction) async {
          DocumentSnapshot snapshot = await transaction.get(docRef);
          if (!snapshot.exists) {
            throw Exception("User does not exist!");
          }
          bool updatedStatus = !(snapshot.data[val]);
          await transaction.update(docRef, {val: updatedStatus}); //await not there in documentation
          return updatedStatus;
        })
        .then((value) => print("$val updated to $value"))
        .catchError((error) => print("Failed to update user status: $error"));
  }

  Future<void> pushUser() async {
    // await updateStatus('isSearching');
    DocumentReference docRef = _firestore.collection('online').document(docId);
    await docRef.setData({
      'docId': docId,
      'created': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeUser() async {
    DocumentReference docRef = _firestore.collection('online').document(docId);
    await docRef.delete();
    // await updateStatus('isSearching');
  }

  Future<void> makeRoom(BuildContext context) async {
    String roomName = "";
    DocumentSnapshot docSnap = await _firestore.collection('online').document(docId).get();
    while (roomName.isEmpty) {
      QuerySnapshot querySnapEnd = await _firestore.collection('online').orderBy('created').endAtDocument(docSnap).getDocuments();
      QuerySnapshot querySnapStart =
          await _firestore.collection('online').orderBy('created').startAfterDocument(docSnap).limit(1).getDocuments();
      int len = querySnapEnd.documents.length;
      if (len % 2 == 1) {
        if (querySnapStart.documents.length == 0) {
          print("not enough users");
        } else {
          roomName += querySnapEnd.documents.elementAt(len - 1).documentID;
          roomName += querySnapStart.documents.first.documentID;
        }
      } else {
        roomName += querySnapEnd.documents.elementAt(len - 2).documentID;
        roomName += querySnapEnd.documents.elementAt(len - 1).documentID;
      }
    }
    print(roomName);
    Navigator.of(context).pop();
    await _joinMeeting(roomName);
  }

  Widget spinner() {
    return Center(child: CircularProgressIndicator(backgroundColor: black, strokeWidth: 12));
  }

  Future<void> callRandom(BuildContext context) async {
    setState(() {
      isLoading = true;
    });
    await pushUser();
    setState(() {
      isLoading = false;
    });
    callRandomDialog(context);
    await makeRoom(context);
    //after successful connection
    // setState(() {
    //   isLoading = true;
    // });
    await removeUser();
    // setState(() {
    //   isLoading = false;
    // });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          leading: Image.asset(
            imgLogo,
            height: 24,
            width: 24,
          ),
          title: Text(
            "NomTalk",
            style: head2,
          ),
          backgroundColor: black,
        ),
        body: FutureBuilder(
          future: initialFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) return Text("[ERROR1]: ${snapshot.error}");
            if (snapshot.connectionState != ConnectionState.done) return spinner();
            return (isMentor) ? mentorFutureBuilder(snapshot) : clientFutureBuilder(snapshot);
          },
        ),
      ),
    );
  }

  Widget clientFutureBuilder(AsyncSnapshot snapshot) {
    DocumentSnapshot data = snapshot.data;
    currUser = UserModel(
      name: data['name'] ?? 'Loading...',
      subscription: data['subscription'] ?? 'none',
      mentorId: data['mentorId'] ?? '',
      isSearching: data['isSearching'] ?? false,
      points: data['points'] ?? 0.0,
      level: data['level'] ?? 1,
    );
    return DefaultTabController(
      length: 4,
      initialIndex: 1,
      child: (isLoading)
          ? spinner()
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: TabBarView(
                    children: [
                      homePage(context),
                      profilePage(context),
                      infoPage(context),
                      extraPage(context),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: navy,
                    border: Border(top: BorderSide(color: white)),
                  ),
                  child: TabBar(
                    indicatorColor: gold,
                    labelColor: gold,
                    unselectedLabelColor: white,
                    indicatorWeight: 0.1,
                    tabs: [
                      Tab(child: Icon(Icons.home)),
                      Tab(child: Icon(Icons.person)),
                      Tab(child: Icon(Icons.info)),
                      Tab(child: Icon(Icons.library_add)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget mentorFutureBuilder(AsyncSnapshot snapshot) {
    currMentor = MentorModel(
      name: snapshot.data['name'] ?? 'Loading...',
      clients: snapshot.data['clients'] ?? [],
    );
    return (isLoading)
        ? spinner()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: currMentor.clients.length,
                  physics: BouncingScrollPhysics(),
                  itemBuilder: (context, i) {
                    return Container(
                      decoration: BoxDecoration(
                        border: Border.symmetric(vertical: BorderSide(color: black, width: 1)),
                        color: gold,
                      ),
                      child: ListTile(
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => ChatView(
                                        myId: docId,
                                        othersId: currMentor.clients[i],
                                        roomId: docId + currMentor.clients[i],
                                      )));
                        },
                        leading: CircleAvatar(
                          backgroundColor: black,
                          child: Icon(Icons.arrow_forward_ios, color: white),
                        ),
                        title: nameFromId(docId, currMentor.clients[i]),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: EdgeInsets.all(MediaQuery.of(context).size.width / 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: black,
                      blurRadius: 4,
                      spreadRadius: 2,
                      offset: Offset(-2, 2),
                    )
                  ],
                  gradient: LinearGradient(
                    colors: [gold, Colors.yellow, white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: GestureDetector(
                  onTap: _logout,
                  child: Align(
                    alignment: Alignment.center,
                    child: Text(
                      "LogOut",
                      style: head1,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ],
          );
  }

  Widget profilePage(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        height: MediaQuery.of(context).size.height - kToolbarHeight - kBottomNavigationBarHeight,
        padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width / 24),
        color: navy,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Welcome, ', style: big),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text("${currUser.name}", style: name, textAlign: TextAlign.center),
                Text("${currUser.points}", style: points, textAlign: TextAlign.center),
                Text("Points", style: body1, textAlign: TextAlign.center),
              ],
            ),
            Column(
              children: [
                Text("Level", style: body1, textAlign: TextAlign.center),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width / 24),
                  height: MediaQuery.of(context).size.width * 0.2,
                  width: MediaQuery.of(context).size.width * 0.2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: white,
                        blurRadius: 10,
                        spreadRadius: 4,
                      )
                    ],
                    border: Border.all(width: 4, color: gold),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [gold, Colors.yellow, white],
                    ),
                  ),
                  child: Center(child: Text("${currUser.level}", style: level)),
                ),
              ],
            ),
            Container(
              padding: EdgeInsets.all(MediaQuery.of(context).size.width / 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: black,
                    blurRadius: 4,
                    spreadRadius: 2,
                    offset: Offset(-2, 2),
                  )
                ],
                gradient: LinearGradient(
                  colors: [gold, Colors.yellow, white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: GestureDetector(
                onTap: _logout,
                child: Align(
                  alignment: Alignment.center,
                  child: Text(
                    "LogOut",
                    style: head1,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget getSubscribedStatus() {
    for (var prod in _products) {
      if (_hasPurchased(prod.id) != null) {
        return Text('Premium Member');
      } else {
        return RaisedButton(
          child: Text('Buy Membership'),
          onPressed: () => _buyProduct(prod),
        );
      }
    }
    return Container();
  }

  Widget homePage(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        height: MediaQuery.of(context).size.height - kToolbarHeight - kBottomNavigationBarHeight,
        padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width / 24),
        color: navy,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                DragTarget<Color>(
                  builder: (context, candidates, rejects) {
                    return candidates.length > 0
                        ? Container(
                            height: MediaQuery.of(context).size.width / 4,
                            width: MediaQuery.of(context).size.width / 4,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: white,
                            ),
                          )
                        : Container(
                            height: MediaQuery.of(context).size.width / 4,
                            width: MediaQuery.of(context).size.width / 4,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              // border: Border.all(color: white, width: 2),
                            ),
                            child: Center(
                              child: Text(
                                'Swipe here to call Random',
                                style: head2.copyWith(fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                  },
                  onWillAccept: (val) => true,
                  onAccept: (val) {
                    print('Calling Random');
                    callRandom(context);
                  },
                  onLeave: (val) {},
                ),
                Draggable<Color>(
                  axis: Axis.horizontal,
                  data: Colors.yellow,
                  child: Image.asset(
                    imgCall,
                    height: MediaQuery.of(context).size.width / 4,
                    width: MediaQuery.of(context).size.width / 4,
                  ),
                  childWhenDragging: Container(),
                  feedback: Image.asset(
                    imgCall,
                    height: MediaQuery.of(context).size.width / 4,
                    width: MediaQuery.of(context).size.width / 4,
                  ),
                ),
                DragTarget<Color>(
                  builder: (context, candidates, rejects) {
                    return candidates.length > 0
                        ? Container(
                            height: MediaQuery.of(context).size.width / 4,
                            width: MediaQuery.of(context).size.width / 4,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: white,
                            ),
                          )
                        : Container(
                            height: MediaQuery.of(context).size.width / 4,
                            width: MediaQuery.of(context).size.width / 4,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              // border: Border.all(color: white, width: 2),
                            ),
                            child: Center(
                              child: Text(
                                'Swipe here to call Instructor',
                                style: head2.copyWith(fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                  },
                  onWillAccept: (val) => true,
                  onAccept: (val) {
                    print('Calling Mentor');
                    //TODO: check for subscription when adding payment
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ChatView(
                                  myId: docId,
                                  othersId: currUser.mentorId,
                                  roomId: currUser.mentorId + docId,
                                )));
                  },
                  onLeave: (val) {},
                ),
              ],
            ),
            getSubscribedStatus(),
            RaisedButton(
              color: white,
              onPressed: (currUser.subscription == 'none') ? () {} : () {},
              child: (currUser.subscription == 'none') ? Text('Buy') : Text('Purchased'),
            ),
            // Row(
            //   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            //   children: [
            //     RaisedButton.icon(
            //       elevation: 8,
            //       padding: EdgeInsets.all(MediaQuery.of(context).size.height * 0.02),
            //       shape: RoundedRectangleBorder(
            //         borderRadius: BorderRadius.circular(8),
            //       ),
            //       color: white,
            //       icon: Icon(
            //         Icons.call,
            //         size: MediaQuery.of(context).size.width / 16,
            //         color: Colors.blue,
            //       ),
            //       label: Text('Random', style: head1),
            //       onPressed: () {
            //         callRandom(context);
            // ratingDialog(context);
            //       },
            //     ),
            //     RaisedButton.icon(
            //       elevation: 8,
            //       padding: EdgeInsets.all(MediaQuery.of(context).size.height * 0.02),
            //       shape: RoundedRectangleBorder(
            //         borderRadius: BorderRadius.circular(8),
            //       ),
            //       color: white,
            //       icon: Icon(
            //         Icons.call,
            //         size: MediaQuery.of(context).size.width / 16,
            //         color: Colors.green,
            //       ),
            //       label: Text('Instructor', style: head1),
            //       onPressed: () {
            //         //TODO: check for subscription when adding payment
            //         Navigator.push(
            //             context,
            //             MaterialPageRoute(
            //                 builder: (_) => ChatView(
            //                       myId: docId,
            //                       othersId: currUser.mentorId,
            //                       roomId: currUser.mentorId + docId,
            //                     )));
            //       },
            //     ),
            //   ],
            // ),
            // Row(
            //   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            //   children: [
            //     RaisedButton(
            //       onPressed: () {
            //         pushUser();
            //       },
            //       child: Text(
            //         "Push",
            //         style: TextStyle(color: Colors.white),
            //       ),
            //       color: Colors.red,
            //     ),
            //     RaisedButton(
            //       onPressed: () {
            //         removeUser();
            //       },
            //       child: Text(
            //         "Pop",
            //         style: TextStyle(color: Colors.white),
            //       ),
            //       color: Colors.red,
            //     ),
            //     RaisedButton(
            //       onPressed: () {
            //         makeRoom();
            //       },
            //       child: Text(
            //         "Connect",
            //         style: TextStyle(color: Colors.white),
            //       ),
            //       color: Colors.red,
            //     ),
            //   ],
            // ),
            // StreamBuilder<QuerySnapshot>(
            //   stream: _firestore.collection('online').orderBy('created').snapshots(),
            //   builder: (context, snapshot) {
            //     if (snapshot.hasError) return Text("[ERROR]: ${snapshot.error}");
            //     if (!snapshot.hasData) return Text('Loading...');
            //     return ListView.builder(
            //       shrinkWrap: true,
            //       itemCount: snapshot.data.documents.length,
            //       itemBuilder: (context, i) {
            //         return ListTile(
            //           leading: CircleAvatar(
            //             backgroundColor: (i % 2 == 0) ? Colors.blue : Colors.red,
            //           ),
            //           title: Text(snapshot.data.documents.elementAt(i).data['docId']),
            //           subtitle: Text(snapshot.data.documents.elementAt(i).data['created'].toDate().toString()),
            //         );
            //       },
            //     );
            //   },
            // ),
          ],
        ),
      ),
    );
  }

  Widget infoPage(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        height: MediaQuery.of(context).size.height - kToolbarHeight - kBottomNavigationBarHeight,
        padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width / 24),
        color: navy,
        child: Center(
          child: Text(
            'We help you in improving your English Fluency by pairing you with others who also want to learn English.\n\nContact Us: neonfluency@gmail.com',
            style: head2,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget extraPage(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        height: MediaQuery.of(context).size.height - kToolbarHeight - kBottomNavigationBarHeight,
        padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width / 24),
        color: navy,
        child: Center(
          child: Text(
            'Coming Soon ...',
            style: head2,
          ),
        ),
      ),
    );
  }

  Future<String> addChatroom(String mentorId, String clientId) async {
    DocumentReference docRef = _firestore.collection('chatrooms').document(mentorId + clientId);
    DocumentSnapshot snap = await docRef.get();
    if (snap.exists) return snap.data['clientId'];
    //get mentor and user details
    DocumentSnapshot userSnap = await _firestore.collection('users').document(clientId).get();
    DocumentSnapshot mentorSnap = await _firestore.collection('mentors').document(mentorId).get();
    // make room as it does not exist
    await docRef.setData({
      'mentorId': mentorSnap.data['name'],
      'clientId': userSnap.data['name'],
    });
    return userSnap.data['name'];
  }

  Widget nameFromId(String mentorId, String clientId) {
    return FutureBuilder(
      future: addChatroom(mentorId, clientId),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Text("[ERROR]: ${snapshot.error}");
        if (!snapshot.hasData) return Text('Loading...');
        return Text(snapshot.data, style: head1);
      },
    );
  }
}
