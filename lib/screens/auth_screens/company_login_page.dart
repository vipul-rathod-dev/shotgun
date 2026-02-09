import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shotgun/auth/controllers/company_login_controller.dart';

class CompanyLoginPage extends StatelessWidget {
  final VoidCallback onSwitchToAdmin;
  const CompanyLoginPage({super.key, required this.onSwitchToAdmin});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CompanyLoginController(),
      child: Consumer<CompanyLoginController>(
        builder: (context, controller, _) {
          return Scaffold(
            body: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 600;
                final maxWidth = isWide ? 420.0 : double.infinity;

                return Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isWide ? 0 : 20,
                      vertical: 32,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: Card(
                        elevation: isWide ? 6 : 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Form(
                            key: controller.formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  "Company Login",
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: isWide ? 28 : 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 32),

                                _buildTextField(
                                  controller.companyController,
                                  label: "Company Name",
                                  icon: Icons.business,
                                  validator: (v) => v == null || v.trim().isEmpty
                                      ? "Please enter company name"
                                      : null,
                                ),

                                const SizedBox(height: 16),

                                _buildTextField(
                                  controller.emailController,
                                  label: "Email",
                                  icon: Icons.email,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return "Enter email";
                                    }
                                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                                        .hasMatch(v)) {
                                      return "Invalid email";
                                    }
                                    return null;
                                  },
                                ),

                                const SizedBox(height: 16),

                                _buildTextField(
                                  controller.passwordController,
                                  label: "Password",
                                  icon: Icons.lock,
                                  obscureText: true,
                                  validator: (v) => v == null || v.isEmpty
                                      ? "Enter password"
                                      : null,
                                ),

                                const SizedBox(height: 12),

                                Row(
                                  children: [
                                    Checkbox(
                                      value: controller.rememberMe,
                                      onChanged: controller.toggleRememberMe,
                                    ),
                                    const Text("Remember Me"),
                                  ],
                                ),

                                const SizedBox(height: 24),

                                SizedBox(
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: controller.isLoading
                                        ? null
                                        : () async {
                                            if (!controller.formKey.currentState!
                                                .validate()) {
                                              return;
                                            }

                                            try {
                                              await controller.login(context);
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
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text("Login"),
                                  ),
                                ),

                                const SizedBox(height: 20),

                                TextButton.icon(
                                  onPressed: onSwitchToAdmin,
                                  icon: const Icon(
                                      Icons.admin_panel_settings),
                                  label: const Text(
                                    "Admin Login",
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

  Widget _buildTextField(
    TextEditingController controller, {
    required String label,
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
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
