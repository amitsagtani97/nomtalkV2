import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:talk_english/views/homeView.dart';

import 'constants.dart';
import 'views/signInView.dart';

void main() {
  InAppPurchaseConnection.enablePendingPurchases();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NomTalk',
      theme: ThemeData(
        primaryColor: gold,
        accentColor: white,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: StreamBuilder(
        stream: FirebaseAuth.instance.onAuthStateChanged,
        builder: (ctx, userSnapshot) {
          if (userSnapshot.hasData) {
            return HomeView();
          } else if (userSnapshot.hasError) {
            return CircularProgressIndicator();
          }
          return SignInView();
        },
      ),
    );
  }
}
