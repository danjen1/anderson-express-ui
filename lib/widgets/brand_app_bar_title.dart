import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BrandAppBarTitle extends StatelessWidget {
  const BrandAppBarTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Anderson Express Cleaning Service',
      style: GoogleFonts.oregano(fontSize: 34, fontWeight: FontWeight.w600),
    );
  }
}
