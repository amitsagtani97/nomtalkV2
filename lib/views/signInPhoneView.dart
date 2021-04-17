import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:talk_english/models/userModel.dart';

import '../constants.dart';

class SignInPhone extends StatefulWidget {
  @override
  _SignInPhoneState createState() => _SignInPhoneState();
}

class _SignInPhoneState extends State<SignInPhone> {
  String countryCode = "+91", phoneNumber = "", verificationId, otp, authStatus = "", name = "";
  final _auth = FirebaseAuth.instance;
  final _firestore = Firestore.instance;
  bool isLoading = false;

  Future<void> verifyPhoneNumber(BuildContext context) async {
    setState(() {
      isLoading = true;
    });
    await _auth.verifyPhoneNumber(
      phoneNumber: countryCode + phoneNumber,
      timeout: const Duration(seconds: 15),
      verificationCompleted: (AuthCredential authCredential) {
        setState(() {
          authStatus = "Your account is successfully verified";
        });
      },
      verificationFailed: (AuthException authException) {
        setState(() {
          authStatus = "Authentication failed";
        });
      },
      codeSent: (String verId, [int forceCodeResent]) {
        verificationId = verId;
        setState(() {
          authStatus = "OTP has been successfully sent";
          isLoading = false;
        });
        otpDialogBox(context);
//        otpDialogBox(context).then((value) {});
      },
      codeAutoRetrievalTimeout: (String verId) {
        verificationId = verId;
        setState(() {
          authStatus = "TIMEOUT";
        });
      },
    );
  }

  otpDialogBox(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return new AlertDialog(
          title: Text('Enter your OTP'),
          content: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                border: new OutlineInputBorder(
                  borderRadius: const BorderRadius.all(
                    const Radius.circular(8),
                  ),
                ),
              ),
              onChanged: (value) {
                otp = value;
              },
            ),
          ),
          contentPadding: EdgeInsets.all(10.0),
          actions: <Widget>[
            FlatButton(
              onPressed: () {
                Navigator.of(context).pop();
                signIn(otp);
              },
              child: Text(
                'Submit',
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> signIn(String otp) async {
    setState(() {
      isLoading = true;
    });
    AuthResult result = await _auth.signInWithCredential(
      PhoneAuthProvider.getCredential(
        verificationId: verificationId,
        smsCode: otp,
      ),
    );
    await addUser(result.user);
    setState(() {
      isLoading = false;
    });
    Navigator.pop(context); // for removing sign in type selection screen
  }

  Future<void> addUser(FirebaseUser user) async {
    DocumentSnapshot userSnapshot = await _firestore.collection('users').document(user.uid).get();
    if (userSnapshot.exists) return;

    // await _firestore.collection('users').document(user.uid).get().then((snapshot) {
    //   if (!snapshot.exists) return;
    // });
    print('New User');
    UserModel newUser = UserModel(name: name);
    await _firestore.collection('users').document(user.uid).setData({
      'name': newUser.name,
      'points': newUser.points,
      'level': newUser.level,
      'isSearching': newUser.isSearching,
      'subscription': newUser.subscription,
      'mentorId': newUser.mentorId,
    });
  }

  Widget spinner() {
    return Center(child: CircularProgressIndicator(backgroundColor: black, strokeWidth: 12));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: (isLoading)
          ? spinner()
          : SingleChildScrollView(
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
                      child: Center(
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
                            children: <Widget>[
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
                                    hintStyle: new TextStyle(color: Colors.grey[800]),
                                    labelText: "User Name",
                                    hintText: "For 1st time signing in only",
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
                                  keyboardType: TextInputType.phone,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: const BorderRadius.all(
                                        const Radius.circular(8),
                                      ),
                                    ),
                                    filled: true,
                                    prefixText: '+91 \t ',
                                    prefixIcon: Icon(
                                      Icons.phone_iphone,
                                      color: black,
                                    ),
                                    hintStyle: new TextStyle(color: Colors.grey[800]),
                                    labelText: "Mobile number",
                                    hintText: "Enter Phone Number",
                                    fillColor: Colors.white70,
                                  ),
                                  onChanged: (value) {
                                    phoneNumber = value;
                                  },
                                ),
                              ),
                              RaisedButton(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                onPressed: () => phoneNumber.length < 10 ? null : verifyPhoneNumber(context),
                                child: Text(
                                  "Send OTP",
                                  style: head1,
                                ),
                                elevation: 8.0,
                                color: white,
                              ),
                              // Text(
                              //   authStatus == "" ? "" : authStatus,
                              //   style: TextStyle(color: authStatus.contains("fail") || authStatus.contains("TIMEOUT") ? Colors.red : Colors.green),
                              // ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
