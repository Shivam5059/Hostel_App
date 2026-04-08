import 'package:flutter/material.dart';
import '../../user_data.dart';
import '../../theme.dart';
import '../../api_calls.dart';
import '../auth/login_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  bool _loading = false;
  bool _isEditing = false;
  
  // Controllers for editing
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: UserSession.name);
    _phoneController = TextEditingController(text: UserSession.phone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _refreshProfile() async {
    if (UserSession.userId == null) return;
    setState(() => _loading = true);
    final data = await ApiManager.fetchUserProfile(UserSession.userId!);
    if (mounted) setState(() => _loading = false);
    if (data != null) {
      setState(() {
        UserSession.updateFromMap(data);
        _nameController.text = UserSession.name ?? '';
        _phoneController.text = UserSession.phone ?? '';
      });
    }
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing) {
        // Reset controllers on cancel
        _nameController.text = UserSession.name ?? '';
        _phoneController.text = UserSession.phone ?? '';
      }
    });
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name must be at least 2 characters long')),
      );
      return;
    }

    setState(() => _loading = true);
    final (ok, err) = await ApiManager.updateUserProfile(
      UserSession.userId!,
      name: name,
      phone: phone,
    );
    
    if (mounted) {
       setState(() => _loading = false);
       if (ok) {
         setState(() => _isEditing = false);
         await _refreshProfile();
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Profile updated successfully'), backgroundColor: Colors.green),
           );
         }
       } else {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(err ?? 'Failed to update')),
         );
       }
    }
  }

  void _showPasswordDialog() {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Password'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: oldCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Current Password', prefixIcon: Icon(Icons.lock_outline))),
            const SizedBox(height: 12),
            TextField(controller: newCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'New Password', prefixIcon: Icon(Icons.lock_reset))),
            const SizedBox(height: 12),
            TextField(controller: confirmCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm Password', prefixIcon: Icon(Icons.check_circle_outline))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (newCtrl.text.length < 8) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Password must be at least 8 characters')));
                return;
              }
              if (newCtrl.text != confirmCtrl.text) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
                return;
              }
              final (ok, err) = await ApiManager.updatePassword(UserSession.userId!, oldCtrl.text, newCtrl.text);
              if (ok) {
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated successfully'), backgroundColor: Colors.green));
                }
              } else {
                if (mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(err ?? 'Failed to update')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && !_isEditing) return const Center(child: CircularProgressIndicator());
    
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // Header Section
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                 radius: 60,
                 backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                 child: Text(
                    UserSession.name?.isNotEmpty == true ? UserSession.name![0].toUpperCase() : '?', 
                    style: const TextStyle(fontSize: 48, color: AppTheme.primaryColor, fontWeight: FontWeight.bold)
                 ),
              ),
              if (!_isEditing) GestureDetector(
                onTap: _toggleEdit,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle),
                  child: const Icon(Icons.edit, color: Colors.white, size: 20),
                ),
              ),
            ],
          ).animate().fadeIn().scale(),
          const SizedBox(height: 24),
          
          if (!_isEditing) ...[
            Text(
              UserSession.name ?? 'Guest User',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 8),
            Container(
               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
               decoration: BoxDecoration(
                 color: AppTheme.secondaryColor.withValues(alpha: 0.1),
                 borderRadius: BorderRadius.circular(20),
               ),
               child: Text(
                 UserSession.role ?? 'UNKNOWN',
                 style: const TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold, letterSpacing: 1.2),
               ),
            ).animate().fadeIn(delay: 200.ms),
          ] else ...[
            const Text("Editing Profile", style: TextStyle(fontSize: 18, color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
          ],
          
          const SizedBox(height: 40),
          
          // Info Cards Section
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                 BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 5))
              ],
            ),
            child: Column(
              children: [
                _buildInfoRow(
                  Icons.email_outlined, 
                  'Email Address', 
                  UserSession.email ?? 'Not available',
                  editable: false
                ),
                const Divider(height: 32),
                _buildInfoRow(
                  Icons.person_outline, 
                  'Full Name', 
                  UserSession.name ?? 'Not set',
                  editable: true,
                  controller: _nameController
                ),
                const Divider(height: 32),
                _buildInfoRow(
                  Icons.phone_outlined, 
                  'Phone Number', 
                  UserSession.phone ?? 'Not set',
                  editable: true,
                  controller: _phoneController,
                  keyboardType: TextInputType.phone
                ),
                
                if (UserSession.role == 'STUDENT' && UserSession.rollNo != null) ...[
                   const Divider(height: 32),
                   _buildInfoRow(Icons.badge_outlined, 'Roll Number', UserSession.rollNo!),
                   if (UserSession.hostelName != null) ...[
                     const Divider(height: 32),
                     _buildInfoRow(Icons.apartment_outlined, 'Hostel', UserSession.hostelName!),
                   ],
                   if (UserSession.roomNumber != null) ...[
                     const Divider(height: 32),
                     _buildInfoRow(Icons.meeting_room_outlined, 'Room', UserSession.roomNumber!),
                   ],
                ],
              ],
            )
          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),

          const SizedBox(height: 32),

          // Action Buttons
          if (_isEditing) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _toggleEdit,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _loading 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ).animate().fadeIn().slideY(begin: 0.2),
          ] else ...[
            OutlinedButton.icon(
              onPressed: _showPasswordDialog,
              icon: const Icon(Icons.lock_reset_rounded),
              label: const Text('Change Password'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                side: const BorderSide(color: AppTheme.primaryColor),
                foregroundColor: AppTheme.primaryColor,
              ),
            ).animate().fadeIn(delay: 350.ms),

            const SizedBox(height: 48),
            
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                   UserSession.logout();
                   Navigator.of(context).pushAndRemoveUntil(
                     MaterialPageRoute(builder: (_) => const LoginScreen()),
                     (route) => false,
                   );
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign Out', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ).animate().fadeIn(delay: 400.ms).scale(),
          ],
        ],
      )
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {
    bool editable = false, 
    TextEditingController? controller,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppTheme.primaryColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13)),
              const SizedBox(height: 2),
              if (_isEditing && editable && controller != null) 
                TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                    border: UnderlineInputBorder(),
                  ),
                  style: const TextStyle(color: AppTheme.textPrimaryColor, fontSize: 16, fontWeight: FontWeight.w600),
                )
              else
                Text(value, style: const TextStyle(color: AppTheme.textPrimaryColor, fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
        )
      ],
    );
  }
}
