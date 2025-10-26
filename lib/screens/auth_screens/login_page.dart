import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shotgun/screens/auth_screens/login_controller.dart';
import 'package:shotgun/widgets/custom_textfield.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  void _navigateByRole(BuildContext context, String role) {
    final routes = {
      'admin': '/admin',
      'supervisor': '/supervisor',
      'staff': '/staff',
    };
    Navigator.pushReplacementNamed(context, routes[role] ?? '/staff');
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LoginController(),
      builder: (context, _) {
        final controller = context.watch<LoginController>();

        return Scaffold(
          backgroundColor: Colors.grey[100],
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: (!controller.isLoaded)
                ? const Center(child: CircularProgressIndicator())
                : Form(
                    child: Column(
                      children: [
                        Text(
                          "Login",
                          style: GoogleFonts.poppins(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 30),
                        CustomTextField(
                          controller: controller.emailController,
                          label: "Email",
                          icon: Icons.email,
                          validator: (value) =>
                              value!.isEmpty ? "Enter your email" : null,
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: controller.passwordController,
                          label: "Password",
                          isPassword: true,
                          icon: Icons.lock,
                          validator: (value) =>
                              value!.isEmpty ? "Enter your password" : null,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: controller.rememberMe,
                                  onChanged: controller.toggleRememberMe,
                                ),
                                const Text("Remember Me"),
                              ],
                            ),
                            TextButton(
                              onPressed: () async {
                                final email =
                                    controller.emailController.text.trim();
                                if (email.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Enter your email first"),
                                    ),
                                  );
                                  return;
                                }
                                try {
                                  await controller.resetPassword(email);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text("Password reset email sent"),
                                    ),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.toString())),
                                  );
                                }
                              },
                              child: const Text("Forgot Password?"),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () async {
                            try {
                              final role = await controller.login(
                                controller.emailController.text.trim(),
                                controller.passwordController.text.trim(),
                              );
                              if (context.mounted) _navigateByRole(context, role);
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            }
                          },
                          child: const Text('Login'),
                        ),
                      ],
                    ),
                  )
              
            ),
          ),
        );
      },
    );
  }
}
