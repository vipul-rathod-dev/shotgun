import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shotgun/screens/auth_screens/login_controller.dart';
import 'package:shotgun/widgets/custom_textfield.dart';

class LoginPage extends StatelessWidget {
  final VoidCallback onSwitchToCompany;

  const LoginPage({
    super.key,
    required this.onSwitchToCompany,
  });

  static const Color primary = Color(0xFF3F51B5);
  static const Color darkBlue = Color(0xFF172B88);
  static const Color lightBlue = Color(0xFF7986CB);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LoginController(),
      child: Consumer<LoginController>(
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
                    ? 460.0
                    : isTablet
                        ? 450.0
                        : width - 32;

                final horizontalPadding = isMobile ? 16.0 : 24.0;

                return Stack(
                  children: [
                    // -------------------------------------------------------
                    // BACKGROUND
                    // -------------------------------------------------------
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

                    // -------------------------------------------------------
                    // BACKGROUND DECORATIONS
                    // -------------------------------------------------------
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

                    // -------------------------------------------------------
                    // DECORATIVE EYEWEAR
                    // -------------------------------------------------------
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

                    // -------------------------------------------------------
                    // MAIN CONTENT
                    // -------------------------------------------------------
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
                                // -------------------------------------------------
                                // LOGO
                                // -------------------------------------------------
                                _buildLogo(
                                  isMobile: isMobile,
                                ),

                                SizedBox(
                                  height: isMobile ? 12 : 16,
                                ),

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
                                  'Administrator Portal',
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

                                // -------------------------------------------------
                                // LOGIN CARD
                                // -------------------------------------------------
                                _buildLoginCard(
                                  context,
                                  controller,
                                  isMobile: isMobile,
                                ),

                                SizedBox(
                                  height: isMobile ? 18 : 22,
                                ),

                                // -------------------------------------------------
                                // FOOTER
                                // -------------------------------------------------
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
        borderRadius: BorderRadius.circular(isMobile ? 20 : 23),
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
    LoginController controller, {
    required bool isMobile,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 22 : 30),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------------------------------------------------------------
          // TITLE
          // ---------------------------------------------------------------

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
            'Sign in to your administrator account',
            style: GoogleFonts.poppins(
              fontSize: isMobile ? 13 : 14,
              color: const Color(0xFF737B91),
            ),
          ),

          SizedBox(
            height: isMobile ? 22 : 26,
          ),

          // ---------------------------------------------------------------
          // EMAIL
          // ---------------------------------------------------------------

          CustomTextField(
            controller: controller.emailController,
            label: 'Email Address',
            hintText: 'Enter your email address',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [
              AutofillHints.username,
              AutofillHints.email,
            ],
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Enter your email';
              }

              return null;
            },
          ),

          const SizedBox(height: 16),

          // ---------------------------------------------------------------
          // PASSWORD
          // ---------------------------------------------------------------

          CustomTextField(
            controller: controller.passwordController,
            label: 'Password',
            hintText: 'Enter your password',
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            autofillHints: const [
              AutofillHints.password,
            ],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Enter your password';
              }

              return null;
            },
          ),

          const SizedBox(height: 8),

          // ---------------------------------------------------------------
          // REMEMBER + FORGOT
          // ---------------------------------------------------------------

          Row(
            children: [
              Expanded(
                child: InkWell(
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
                      Flexible(
                        child: Text(
                          'Remember Me',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF30374A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              TextButton(
                onPressed: () async {
                  final email =
                      controller.emailController.text.trim();

                  if (email.isEmpty) {
                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      _snackBar(
                        'Enter your email first',
                        isError: true,
                      ),
                    );

                    return;
                  }

                  try {
                    await controller.resetPassword(email);

                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      _snackBar(
                        'Password reset email sent',
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
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
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                ),
                child: Text(
                  'Forgot Password?',
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: primary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ---------------------------------------------------------------
          // LOGIN BUTTON
          // ---------------------------------------------------------------

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
                        final messenger =
                            ScaffoldMessenger.of(context);

                        try {
                          await controller.login();

                          // AuthGate handles successful authentication.
                        } catch (e) {
                          if (!context.mounted) return;

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

          // ---------------------------------------------------------------
          // OR DIVIDER
          // ---------------------------------------------------------------

          Row(
            children: [
              Expanded(
                child: Divider(
                  color: const Color(0xFFDDE1EB),
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
              Expanded(
                child: Divider(
                  color: const Color(0xFFDDE1EB),
                  thickness: 1,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ---------------------------------------------------------------
          // COMPANY LOGIN
          // ---------------------------------------------------------------

          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: onSwitchToCompany,
              icon: const Icon(
                Icons.business_outlined,
                size: 20,
              ),
              label: Text(
                'Login to Company Account',
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
    );
  }

  // ===========================================================================
  // DECORATIVE CIRCLE
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
// CUSTOM GLASSES LOGO
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

    // Bridge.
    canvas.drawLine(
      Offset(size.width * 0.40, size.height * 0.25),
      Offset(size.width * 0.60, size.height * 0.25),
      paint,
    );

    // Left temple.
    canvas.drawLine(
      Offset(2, size.height * 0.22),
      Offset(0, size.height * 0.12),
      paint,
    );

    // Right temple.
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