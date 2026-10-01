import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as google_web;

Widget buildGoogleSignInButton() {
  return SizedBox(
    height: 44,
    child: google_web.renderButton(),
  );
}
