import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shotgun/auth/controllers/admin_login_controller.dart';
import 'package:shotgun/widgets/custom_textfield.dart';

class LoginPage extends StatelessWidget {
  final VoidCallback onSwitchToCompany;
  const LoginPage({super.key, required this.onSwitchToCompany});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AdminLoginController(),
      child: Consumer<AdminLoginController>(
        builder: (context, controller, _) {
          return Scaffold(
            body: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 900;
                final isTablet = constraints.maxWidth >= 600;

                final maxWidth = isDesktop
                    ? 420.0
                    : isTablet
                        ? 460.0
                        : double.infinity;

                final horizontalPadding = isDesktop
                    ? 32.0
                    : isTablet
                        ? 28.0
                        : 20.0;

                return Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 40,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: Card(
                        elevation: isDesktop ? 8 : 0,
                        surfaceTintColor: Theme.of(context).colorScheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Form(
                            key: controller.formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "Login",
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 30),

                                // Email
                                CustomTextField(
                                  controller: controller.emailController,
                                  label: "Email",
                                  icon: Icons.email,
                                  keyboardType:
                                      TextInputType.emailAddress,
                                  validator: (value) =>
                                      value!.isEmpty
                                          ? "Enter your email"
                                          : null,
                                ),
                                const SizedBox(height: 16),

                                // Password
                                CustomTextField(
                                  controller: controller.passwordController,
                                  label: "Password",
                                  isPassword: true,
                                  icon: Icons.lock,
                                  validator: (value) =>
                                      value!.isEmpty
                                          ? "Enter your password"
                                          : null,
                                ),
                                const SizedBox(height: 10),

                                // Remember + Forgot
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Checkbox(
                                          value: controller.rememberMe,
                                          onChanged: controller.toggleRememberMe,
                                        ),
                                        Text(
                                          "Remember Me",
                                          style: Theme.of(context).textTheme.bodyMedium,
                                        ),
                                      ],
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        final email = controller
                                            .emailController.text
                                            .trim();
                                        if (email.isEmpty) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  "Enter your email first"),
                                            ),
                                          );
                                          return;
                                        }
                                        try {
                                          await controller
                                              .resetPassword(email);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  "Password reset email sent"),
                                            ),
                                          );
                                        } catch (e) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                                content:
                                                    Text(e.toString())),
                                          );
                                        }
                                      },
                                      child:
                                          Text(
                                            "Forgot Password?",
                                            style: Theme.of(context).textTheme.bodyMedium,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // Login Button
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: controller.isLoading
                                        ? null
                                        : () async {
                                            try {
                                              await controller.login(context);
                                              // AuthGate handles navigation
                                            } catch (e) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content:
                                                      Text(e.toString()),
                                                ),
                                              );
                                            }
                                          },
                                    child: controller.isLoading
                                        ? SizedBox(
                                            height: 20,
                                            width: 20,
                                            child:
                                                CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(
                                                    Theme.of(context).colorScheme.onPrimary,
                                                  ),
                                                ),
                                          )
                                        : const Text("Login"),
                                  ),
                                ),

                                const SizedBox(height: 24),

                                // Company Login
                                TextButton.icon(
                                  onPressed: () {
                                    onSwitchToCompany();
                                  },
                                  icon: const Icon(
                                      Icons.business_outlined),
                                  label: Text(
                                    "Login to Company Account",
                                    // style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    //   fontWeight: FontWeight.w600,
                                    // ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
