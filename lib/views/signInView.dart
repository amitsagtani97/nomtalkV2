import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:talk_english/models/mentorModel.dart';
import 'package:talk_english/models/userModel.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants.dart';
import 'signInPhoneView.dart';

class SignInView extends StatefulWidget {
  @override
  _SignInViewState createState() => _SignInViewState();
}

class _SignInViewState extends State<SignInView> {
  PageController _pageController = PageController(initialPage: 1, viewportFraction: 0.8);
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _firestore = Firestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  String email = "", password = "", name = "";
  bool isLoading = false;

  Future<void> signInWithGoogle() async {
    GoogleSignInAccount googleSignInAccount = await _googleSignIn.signIn();
    GoogleSignInAuthentication googleSignInAuthentication = await googleSignInAccount.authentication;
    AuthCredential credential = GoogleAuthProvider.getCredential(
      accessToken: googleSignInAuthentication.accessToken,
      idToken: googleSignInAuthentication.idToken,
    );
    AuthResult result = await _auth.signInWithCredential(credential);
    await addUser(result.user);
  }

  Future<void> addUser(FirebaseUser user) async {
    DocumentSnapshot userSnapshot = await _firestore.collection('users').document(user.uid).get();
    if (userSnapshot.exists) return;
    print('New user');
    UserModel newUser = UserModel(name: user.displayName);
    await _firestore.collection('users').document(user.uid).setData({
      'name': newUser.name,
      'points': newUser.points,
      'level': newUser.level,
      'isSearching': newUser.isSearching,
      'subscription': newUser.subscription,
      'mentorId': newUser.mentorId,
    });
  }

  Future<void> nextPage() async {
    await _pageController.nextPage(
      duration: Duration(milliseconds: 300),
      curve: Curves.fastOutSlowIn,
    );
  }

  Future<void> previousPage() async {
    await _pageController.previousPage(
      duration: Duration(milliseconds: 300),
      curve: Curves.fastOutSlowIn,
    );
  }

  _launchURL() async {
    const url = 'https://forms.gle/UzkpoLwn63tEti186';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  Future<void> mentorLogin() async {
    setState(() {
      isLoading = true;
    });
    AuthResult result = await _auth.signInWithEmailAndPassword(email: email, password: password);
    //TODO: add try catch in every Future
    await addMentor(result.user);
    setState(() {
      isLoading = false;
    });
  }

  Future<void> addMentor(FirebaseUser user) async {
    DocumentSnapshot snap = await _firestore.collection('mentors').document(user.uid).get();
    if (snap.exists) return;
    print('New Mentor');
    MentorModel newMentor = MentorModel(name: name);
    await _firestore.collection('mentors').document(user.uid).setData({
      'name': newMentor.name,
      'clients': newMentor.clients,
    });
  }

  Widget page2() {
    return Center(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.5,
        margin: EdgeInsets.symmetric(vertical: MediaQuery.of(context).size.width / 8),
        padding: EdgeInsets.all(MediaQuery.of(context).size.width / 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: black,
              blurRadius: 4,
              spreadRadius: 2,
              offset: Offset(-2, 2),
            )
          ],
          gradient: LinearGradient(
            colors: [black, gold, Colors.yellow, white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Container(
              width: MediaQuery.of(context).size.width * 0.6,
              child: RaisedButton.icon(
                color: white,
                elevation: 8,
                padding: EdgeInsets.symmetric(vertical: MediaQuery.of(context).size.height * 0.02),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                icon: Icon(Icons.call),
                label: Text(
                  'Sign in with Phone',
                  style: head1,
                ),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SignInPhone())),
              ),
            ),
            Container(
              width: MediaQuery.of(context).size.width * 0.6,
              child: RaisedButton.icon(
                  color: white,
                  elevation: 8,
                  padding: EdgeInsets.symmetric(vertical: MediaQuery.of(context).size.height * 0.02),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  icon: Image.asset(
                    imgGoogle,
                    height: 24,
                    width: 24,
                  ),
                  label: Text(
                    'Sign in with Google',
                    style: head1,
                  ),
                  onPressed: () => signInWithGoogle()),
            ),
          ],
        ),
      ),
    );
  }

  Widget page1() {
    return Center(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.5,
        margin: EdgeInsets.symmetric(vertical: MediaQuery.of(context).size.width / 8),
        padding: EdgeInsets.all(MediaQuery.of(context).size.width / 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: black,
              blurRadius: 4,
              spreadRadius: 2,
              offset: Offset(-2, 2),
            )
          ],
          gradient: LinearGradient(
            colors: [black, gold, Colors.yellow, white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: MediaQuery.of(context).size.width * 0.6,
              child: RaisedButton.icon(
                elevation: 8,
                padding: EdgeInsets.symmetric(vertical: MediaQuery.of(context).size.height * 0.02),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                color: white,
                icon: Icon(Icons.font_download),
                label: Text(
                  'Learn English',
                  style: head1,
                ),
                onPressed: nextPage,
              ),
            ),
            Container(
              width: MediaQuery.of(context).size.width * 0.6,
              child: RaisedButton.icon(
                elevation: 8,
                padding: EdgeInsets.symmetric(vertical: MediaQuery.of(context).size.height * 0.02),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                color: white,
                icon: Icon(Icons.supervisor_account),
                label: Text(
                  'Mentor Login',
                  style: head1,
                ),
                onPressed: previousPage,
              ),
            ),
            Container(
              width: MediaQuery.of(context).size.width * 0.6,
              child: RaisedButton.icon(
                elevation: 8,
                padding: EdgeInsets.symmetric(vertical: MediaQuery.of(context).size.height * 0.02),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                color: white,
                icon: Icon(Icons.assignment_ind),
                label: Text(
                  'Become Mentor',
                  style: head1,
                ),
                onPressed: _launchURL,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget page0() {
    return Center(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.5,
        margin: EdgeInsets.symmetric(vertical: MediaQuery.of(context).size.width / 8),
        padding: EdgeInsets.all(MediaQuery.of(context).size.width / 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: black,
              blurRadius: 4,
              spreadRadius: 2,
              offset: Offset(-2, 2),
            )
          ],
          gradient: LinearGradient(
            colors: [black, gold, Colors.yellow, white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: MediaQuery.of(context).size.width * 0.6,
              child: TextField(
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(
                      const Radius.circular(8),
                    ),
                  ),
                  filled: true,
                  prefixIcon: Icon(
                    Icons.account_circle,
                    color: black,
                  ),
                  hintStyle: TextStyle(color: Colors.grey[800]),
                  labelText: "Name",
                  hintText: 'For 1st time login only',
                  fillColor: Colors.white70,
                ),
                onChanged: (value) {
                  name = value;
                },
              ),
            ),
            Container(
              width: MediaQuery.of(context).size.width * 0.6,
              child: TextField(
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(
                      const Radius.circular(8),
                    ),
                  ),
                  filled: true,
                  prefixIcon: Icon(
                    Icons.email,
                    color: black,
                  ),
                  hintStyle: new TextStyle(color: Colors.grey[800]),
                  labelText: "Email",
                  fillColor: Colors.white70,
                ),
                onChanged: (value) {
                  email = value;
                },
              ),
            ),
            Container(
              width: MediaQuery.of(context).size.width * 0.6,
              child: TextField(
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(
                      const Radius.circular(8),
                    ),
                  ),
                  filled: true,
                  prefixIcon: Icon(
                    Icons.vpn_key,
                    color: black,
                  ),
                  hintStyle: new TextStyle(color: Colors.grey[800]),
                  labelText: "Password",
                  fillColor: Colors.white70,
                ),
                onChanged: (value) {
                  password = value;
                },
              ),
            ),
            RaisedButton(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              onPressed: mentorLogin,
              child: Text(
                "Login",
                style: head1,
              ),
              elevation: 7.0,
              color: white,
            ),
          ],
        ),
      ),
    );
  }

  Widget spinner() {
    return Center(child: CircularProgressIndicator());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          height: MediaQuery.of(context).size.height,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                flex: 1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Image.asset(
                      imgLogo,
                      height: MediaQuery.of(context).size.width * 0.2,
                      width: MediaQuery.of(context).size.width * 0.2,
                    ),
                    Text('NomTalk', style: head1),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: PageView(
                  controller: _pageController,
                  children: [
                    page0(),
                    page1(),
                    page2(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
