// import 'package:flutter/material.dart';
// import '../themes/theme_provider.dart';
// import '../widgets/form.dart';
// import 'otp_screen.dart';
// import '../widgets/primary_button.dart';

// class ForgotPasswordScreen extends StatelessWidget {
//   const ForgotPasswordScreen({super.key, required this.themeProvider});

//   final ThemeProvider themeProvider; 

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(),
//       body: SafeArea(
//           child: SingleChildScrollView(
//         child: SizedBox(
//           width: double.infinity,
//           child: Padding(
//             padding: const EdgeInsets.symmetric(
//               horizontal: 20,
//             ),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const SizedBox(height: 16),
//                 const Text(
//                   "Forgot Password?",
//                   style: TextStyle(
//                     fontSize: 24,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//                 const SizedBox(height: 16),
//                 const Text(
//                   "Enter your email address and we will send you the recovery code.",
//                   style: TextStyle(
//                     fontSize: 16,
//                   ),
//                 ),
//                 const SizedBox(height: 24),

//                 //email form

//                 EmailField(
//                   kHint: "Your Email", themeProvider: themeProvider,
//                 ),

//                 const SizedBox(height: 40),

//                 //Send email button
//                 PrimaryButton(
//                   text: "Send",
//                   press: () => Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                       builder: (context) => OtpScreen(themeProvider: themeProvider,),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       )),
//     );
//   }
// }
