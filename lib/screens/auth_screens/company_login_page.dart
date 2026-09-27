import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shotgun/screens/auth_screens/company_login_controller.dart';

class CompanyLoginPage extends StatelessWidget {
  final VoidCallback onSwitchToAdmin;

  const CompanyLoginPage({
    super.key,
    required this.onSwitchToAdmin,
  });

  static const Color primary = Color(0xFF3F51B5);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CompanyLoginController(),
      child: Consumer<CompanyLoginController>(
        builder: (context, controller, _) {
          return Scaffold(
            body: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;

                final isDesktop = width >= 1000;
                final isTablet = width >= 600 && width < 1000;
                final isMobile = width < 600;

                final cardWidth = isDesktop
                    ? 470.0
                    : isTablet
                        ? 450.0
                        : width - 32;

                final horizontalPadding = isMobile ? 16.0 : 24.0;

                return Stack(
                  children: [
                    // ========================================================
                    // BACKGROUND GRADIENT
                    // ========================================================

                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF182A86),
                              Color(0xFF304FC1),
                              Color(0xFF536FD5),
                              Color(0xFF7185DF),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // ========================================================
                    // BACKGROUND CIRCLES
                    // ========================================================

                    Positioned(
                      top: -170,
                      left: -120,
                      child: _circle(
                        size: isMobile ? 300 : 430,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),

                    Positioned(
                      top: -80,
                      left: -40,
                      child: _circle(
                        size: isMobile ? 220 : 320,
                        color: Colors.white.withValues(alpha: 0.055),
                      ),
                    ),

                    Positioned(
                      right: -130,
                      top: height * 0.12,
                      child: _circle(
                        size: isMobile ? 260 : 390,
                        color: Colors.white.withValues(alpha: 0.07),
                      ),
                    ),

                    Positioned(
                      right: -100,
                      bottom: -150,
                      child: _circle(
                        size: isMobile ? 320 : 480,
                        color: Colors.white.withValues(alpha: 0.075),
                      ),
                    ),

                    Positioned(
                      left: -120,
                      bottom: -100,
                      child: _circle(
                        size: isMobile ? 250 : 360,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),

                    // ========================================================
                    // DECORATIVE EYEWEAR
                    // ========================================================

                    if (!isMobile) ...[
                      Positioned(
                        left: -75,
                        top: height * 0.22,
                        child: Transform.rotate(
                          angle: -0.08,
                          child: Opacity(
                            opacity: 0.18,
                            child: Icon(
                              Icons.remove_red_eye_outlined,
                              size: isDesktop ? 180 : 140,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      Positioned(
                        right: -65,
                        bottom: height * 0.12,
                        child: Transform.rotate(
                          angle: 0.08,
                          child: Opacity(
                            opacity: 0.16,
                            child: Icon(
                              Icons.remove_red_eye_outlined,
                              size: isDesktop ? 190 : 150,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],

                    // ========================================================
                    // MAIN CONTENT
                    // ========================================================

                    SafeArea(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                            vertical: isMobile ? 24 : 40,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: cardWidth,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // ==================================================
                                // LOGO
                                // ==================================================

                                _buildLogo(
                                  isMobile: isMobile,
                                ),

                                SizedBox(
                                  height: isMobile ? 12 : 16,
                                ),

                                // ==================================================
                                // SHOTGUN
                                // ==================================================

                                Text(
                                  'SHOTGUN',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: isMobile ? 30 : 36,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 5,
                                    color: Colors.white,
                                  ),
                                ),

                                const SizedBox(height: 2),

                                Text(
                                  'Company Management Portal',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: isMobile ? 13 : 15,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: 1.3,
                                    color: Colors.white.withValues(
                                      alpha: 0.9,
                                    ),
                                  ),
                                ),

                                SizedBox(
                                  height: isMobile ? 22 : 30,
                                ),

                                // ==================================================
                                // LOGIN CARD
                                // ==================================================

                                _buildLoginCard(
                                  context,
                                  controller,
                                  isMobile: isMobile,
                                ),

                                SizedBox(
                                  height: isMobile ? 18 : 22,
                                ),

                                // ==================================================
                                // FOOTER
                                // ==================================================

                                Text(
                                  '© 2025 Shotgun. All rights reserved.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11.5,
                                    color: Colors.white.withValues(
                                      alpha: 0.82,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // LOGO
  // ===========================================================================

  Widget _buildLogo({
    required bool isMobile,
  }) {
    final size = isMobile ? 72.0 : 84.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          isMobile ? 20 : 23,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.35),
            Colors.white.withValues(alpha: 0.12),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: CustomPaint(
          size: Size(
            isMobile ? 46 : 54,
            isMobile ? 30 : 36,
          ),
          painter: _GlassesPainter(),
        ),
      ),
    );
  }

  // ===========================================================================
  // LOGIN CARD
  // ===========================================================================

  Widget _buildLoginCard(
    BuildContext context,
    CompanyLoginController controller, {
    required bool isMobile,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        isMobile ? 22 : 30,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          isMobile ? 22 : 26,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 35,
            spreadRadius: 2,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Form(
        key: controller.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================================================================
            // TITLE
            // ================================================================

            Text(
              'Welcome Back!',
              style: GoogleFonts.poppins(
                fontSize: isMobile ? 27 : 30,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF17213F),
              ),
            ),

            const SizedBox(height: 4),

            Text(
              'Sign in to your company account',
              style: GoogleFonts.poppins(
                fontSize: isMobile ? 13 : 14,
                color: const Color(0xFF737B91),
              ),
            ),

            SizedBox(
              height: isMobile ? 22 : 26,
            ),

            // ================================================================
            // COMPANY NAME
            // ================================================================

            _buildTextField(
              controller.companyController,
              label: 'Company Name',
              hint: 'Enter your company name',
              icon: Icons.business_outlined,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please enter company name';
                }

                return null;
              },
            ),

            const SizedBox(height: 16),

            // ================================================================
            // EMAIL
            // ================================================================

            _buildTextField(
              controller.emailController,
              label: 'Email Address',
              hint: 'Enter your email address',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Enter email';
                }

                if (!RegExp(
                  r'^[^@]+@[^@]+\.[^@]+',
                ).hasMatch(v.trim())) {
                  return 'Invalid email';
                }

                return null;
              },
            ),

            const SizedBox(height: 16),

            // ================================================================
            // PASSWORD
            // ================================================================

            _buildTextField(
              controller.passwordController,
              label: 'Password',
              hint: 'Enter your password',
              icon: Icons.lock_outline_rounded,
              obscureText: true,
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Enter password';
                }

                return null;
              },
            ),

            const SizedBox(height: 8),

            // ================================================================
            // REMEMBER ME
            // ================================================================

            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                controller.toggleRememberMe(
                  !controller.rememberMe,
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: controller.rememberMe,
                    onChanged: controller.toggleRememberMe,
                    activeColor: primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  Text(
                    'Remember Me',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF30374A),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ================================================================
            // LOGIN BUTTON
            // ================================================================

            SizedBox(
              width: double.infinity,
              height: isMobile ? 52 : 54,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xFF3559D8),
                      Color(0xFF294BC5),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: controller.isLoading
                      ? null
                      : () async {
                          if (!controller.formKey.currentState!
                              .validate()) {
                            return;
                          }

                          final messenger =
                              ScaffoldMessenger.of(context);

                          try {
                            await controller.login();

                            // AuthGate handles successful login.
                          } catch (e) {
                            if (!context.mounted) {
                              return;
                            }

                            messenger.showSnackBar(
                              _snackBar(
                                e.toString().replaceFirst(
                                      'Exception: ',
                                      '',
                                    ),
                                isError: true,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.transparent,
                    disabledForegroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: controller.isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Text(
                              'Sign In',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 21,
                            ),
                          ],
                        ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ================================================================
            // OR
            // ================================================================

            Row(
              children: [
                const Expanded(
                  child: Divider(
                    color: Color(0xFFDDE1EB),
                    thickness: 1,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                  ),
                  child: Text(
                    'OR',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF8B91A3),
                    ),
                  ),
                ),
                const Expanded(
                  child: Divider(
                    color: Color(0xFFDDE1EB),
                    thickness: 1,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ================================================================
            // ADMIN LOGIN
            // ================================================================

            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: onSwitchToAdmin,
                icon: const Icon(
                  Icons.admin_panel_settings_outlined,
                  size: 21,
                ),
                label: Text(
                  'Login as Administrator',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primary,
                  side: const BorderSide(
                    color: primary,
                    width: 1.3,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TEXT FIELD
  // ===========================================================================

  Widget _buildTextField(
    TextEditingController controller, {
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.poppins(
        fontSize: 14,
        color: const Color(0xFF252B3D),
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.poppins(
          fontSize: 13,
          color: const Color(0xFF697187),
        ),
        hintStyle: GoogleFonts.poppins(
          fontSize: 13,
          color: const Color(0xFFA1A7B5),
        ),
        prefixIcon: Icon(
          icon,
          color: primary,
          size: 21,
        ),
        filled: true,
        fillColor: const Color(0xFFF8F9FC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(
            color: Color(0xFFDCE1EC),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(
            color: Color(0xFFDCE1EC),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(
            color: primary,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(
            color: Colors.redAccent,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(
            color: Colors.redAccent,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // CIRCLE
  // ===========================================================================

  static Widget _circle({
    required double size,
    required Color color,
  }) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // SNACKBAR
  // ===========================================================================

  static SnackBar _snackBar(
    String message, {
    bool isError = false,
  }) {
    return SnackBar(
      content: Row(
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: Colors.white,
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      behavior: SnackBarBehavior.floating,
      backgroundColor:
          isError ? const Color(0xFFD32F2F) : const Color(0xFF2E7D32),
      duration: const Duration(seconds: 4),
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

// =============================================================================
// GLASSES LOGO
// =============================================================================

class _GlassesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final leftLens = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        2,
        5,
        size.width * 0.38,
        size.height * 0.58,
      ),
      const Radius.circular(10),
    );

    final rightLens = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.60,
        5,
        size.width * 0.38,
        size.height * 0.58,
      ),
      const Radius.circular(10),
    );

    canvas.drawRRect(leftLens, paint);
    canvas.drawRRect(rightLens, paint);

    // Bridge
    canvas.drawLine(
      Offset(size.width * 0.40, size.height * 0.25),
      Offset(size.width * 0.60, size.height * 0.25),
      paint,
    );

    // Left temple
    canvas.drawLine(
      Offset(2, size.height * 0.22),
      Offset(0, size.height * 0.12),
      paint,
    );

    // Right temple
    canvas.drawLine(
      Offset(size.width - 2, size.height * 0.22),
      Offset(size.width, size.height * 0.12),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}