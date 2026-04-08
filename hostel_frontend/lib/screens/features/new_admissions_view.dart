import 'package:flutter/material.dart';
import '../../api_calls.dart';
import '../../theme.dart';
import 'package:flutter_animate/flutter_animate.dart';

// ═══════════════════════════════════════════════════════════
// NEW STUDENTS VIEW — Rector: lists students without a parent
// ═══════════════════════════════════════════════════════════
class NewStudentsView extends StatefulWidget {
  const NewStudentsView({super.key});
  @override
  State<NewStudentsView> createState() => _NewStudentsViewState();
}

class _NewStudentsViewState extends State<NewStudentsView> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { 
      _future = ApiManager.fetchNewStudents(); 
    });
    return;
  }

  void _showSheet(Widget sheet) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => sheet,
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppTheme.accentColor),
                const SizedBox(height: 16),
                const Text('Failed to load new students', style: TextStyle(fontWeight: FontWeight.bold)),
                TextButton(onPressed: _fetch, child: const Text('Retry'))
              ],
            ),
          );
        }

        final students = snap.data ?? [];

        return RefreshIndicator(
          onRefresh: _fetch,
          child: students.isEmpty
              ? SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 72, color: Colors.green.shade200),
                          const SizedBox(height: 16),
                          const Text('All students have parents registered!',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor)),
                          const SizedBox(height: 8),
                          Text('New admissions will appear here.',
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                        ],
                      ).animate().fadeIn(),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  itemCount: students.length,
                  itemBuilder: (context, i) {
                    final s = students[i];
                    final initials = (s['name'] ?? '?').toString().isNotEmpty
                        ? s['name'].toString()[0].toUpperCase()
                        : '?';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                                child: Text(initials, style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 20)),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text('Roll: ${s['roll_no'] ?? 'N/A'}', style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.orange.shade200),
                                ),
                                child: Text('No Parent', style: TextStyle(color: Colors.orange.shade700, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.apartment_outlined, size: 14, color: Colors.grey.shade400),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  s['hostel_name'] != null ? '${s['hostel_name']} — Room ${s['room_number'] ?? 'N/A'}' : 'No room assigned',
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                                ),
                              ),
                              Icon(Icons.calendar_today_outlined, size: 13, color: Colors.grey.shade400),
                              const SizedBox(width: 4),
                              Text(s['created_at']?.toString().split('T').first ?? '', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _showSheet(_LinkExistingParentSheet(
                                    studentId: s['student_id'] as int,
                                    studentName: s['name'] ?? 'Student',
                                    onSuccess: _fetch,
                                  )),
                                  icon: const Icon(Icons.person_search_outlined, size: 16),
                                  label: const Text('Existing Parent', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.primaryColor,
                                    side: const BorderSide(color: AppTheme.primaryColor),
                                    padding: const EdgeInsets.symmetric(vertical: 11),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _showSheet(_RegisterParentSheet(
                                    studentId: s['student_id'] as int,
                                    studentName: s['name'] ?? 'Student',
                                    onSuccess: _fetch,
                                  )),
                                  icon: const Icon(Icons.person_add_outlined, size: 16, color: Colors.white),
                                  label: const Text('New Parent', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.secondaryColor,
                                    padding: const EdgeInsets.symmetric(vertical: 11),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: (60 * i).ms).slideY(begin: 0.05);
                  },
                ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
// NEW ADMISSION VIEW — Rector: register a student
// ═══════════════════════════════════════════════════════════
class NewAdmissionView extends StatefulWidget {
  const NewAdmissionView({super.key});
  @override
  State<NewAdmissionView> createState() => _NewAdmissionViewState();
}

class _NewAdmissionViewState extends State<NewAdmissionView> {
  final _formKey     = GlobalKey<FormState>();
  final _emailCtrl   = TextEditingController();
  final _rollCtrl    = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  bool _loading      = false;
  String? _lastTempPassword;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _rollCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _lastTempPassword = null; });

    final (ok, errMsg, data) = await ApiManager.registerNewStudent(
      email:  _emailCtrl.text.trim(),
      rollNo: _rollCtrl.text.trim(),
      phone:  _phoneCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (ok) {
      final tmp = data?['temp_password'] as String? ?? _rollCtrl.text.trim();
      setState(() {
        _lastTempPassword = tmp;
        _emailCtrl.clear();
        _phoneCtrl.clear();
        _rollCtrl.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Student registered successfully!'),
        backgroundColor: Colors.green,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(errMsg ?? 'Registration failed'),
        backgroundColor: AppTheme.accentColor,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      physics: const BouncingScrollPhysics(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.how_to_reg_outlined, color: AppTheme.primaryColor, size: 22),
                SizedBox(width: 8),
                Text('Register New Student',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor)),
              ],
            ),
            const SizedBox(height: 6),
            Text('A temporary password equal to the roll number will be created.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
            const SizedBox(height: 24),

            _field(_emailCtrl, 'Student Email', Icons.email_outlined,
                enabled: !_loading,
                keyboard: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email is required';
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) return 'Enter a valid email';
                  return null;
                }),
            const SizedBox(height: 14),
            _field(_rollCtrl, 'Roll Number', Icons.numbers_rounded,
                enabled: !_loading,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Roll number is required' : null),
            const SizedBox(height: 14),
            _field(_phoneCtrl, 'Phone Number (optional)', Icons.phone_outlined,
                enabled: !_loading,
                keyboard: TextInputType.phone),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _loading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                    : const Text('Register Student',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ),

            if (_lastTempPassword != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: Colors.green.shade600),
                        const SizedBox(width: 8),
                        const Text('Student Registered!',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text('Share the temporary password with the student:',
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: SelectableText(_lastTempPassword!, // Changed to SelectableText for easy copy
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold,
                              letterSpacing: 2, color: AppTheme.primaryColor)),
                    ),
                    const SizedBox(height: 8),
                    Text('The student appears in New Students tab and should update their password on first login.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ).animate().fadeIn().slideY(begin: 0.1),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType? keyboard,
    bool enabled = true,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        validator: validator,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
}

// ═══════════════════════════════════════════════════════════
// REGISTER NEW PARENT bottom sheet
// ═══════════════════════════════════════════════════════════
class _RegisterParentSheet extends StatefulWidget {
  final int studentId;
  final String studentName;
  final Future<void> Function() onSuccess;

  const _RegisterParentSheet({
    required this.studentId,
    required this.studentName,
    required this.onSuccess,
  });

  @override
  State<_RegisterParentSheet> createState() => _RegisterParentSheetState();
}

class _RegisterParentSheetState extends State<_RegisterParentSheet> {
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose();
    _phoneCtrl.dispose(); _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.isEmpty || _emailCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name, Email and Password are required')));
      return;
    }
    setState(() => _loading = true);

    final (ok, errMsg) = await ApiManager.registerAndLinkParent(
      studentId: widget.studentId,
      name:      _nameCtrl.text.trim(),
      email:     _emailCtrl.text.trim(),
      phone:     _phoneCtrl.text.trim(),
      password:  _passwordCtrl.text,
    );

    if (!mounted) return;

    if (ok) {
      Navigator.pop(context);
      await widget.onSuccess();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Parent registered and linked!'), backgroundColor: Colors.green));
    } else {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(errMsg ?? 'Failed to register parent'),
        backgroundColor: AppTheme.accentColor));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _handle(),
            Row(children: [
              const Icon(Icons.family_restroom_outlined, color: AppTheme.secondaryColor, size: 26),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Register New Parent', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('for ${widget.studentName}', style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13)),
              ]),
            ]),
            const SizedBox(height: 20),
            _tf(_nameCtrl,     'Parent Full Name', Icons.person_outlined, enabled: !_loading),
            const SizedBox(height: 12),
            _tf(_emailCtrl,    'Parent Email',     Icons.email_outlined, keyboard: TextInputType.emailAddress, enabled: !_loading),
            const SizedBox(height: 12),
            _tf(_phoneCtrl,    'Phone (Optional)', Icons.phone_outlined,  keyboard: TextInputType.phone, enabled: !_loading),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              enabled: !_loading,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outlined),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _loading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                  : const Text('Register & Link Parent',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tf(TextEditingController c, String label, IconData icon, {TextInputType? keyboard, bool enabled = true}) =>
      TextField(
        controller: c,
        keyboardType: keyboard,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
}

// ═══════════════════════════════════════════════════════════
// LINK EXISTING PARENT bottom sheet (searchable)
// ═══════════════════════════════════════════════════════════
class _LinkExistingParentSheet extends StatefulWidget {
  final int studentId;
  final String studentName;
  final Future<void> Function() onSuccess;

  const _LinkExistingParentSheet({
    required this.studentId,
    required this.studentName,
    required this.onSuccess,
  });

  @override
  State<_LinkExistingParentSheet> createState() => _LinkExistingParentSheetState();
}

class _LinkExistingParentSheetState extends State<_LinkExistingParentSheet> {
  List<dynamic> _all      = [];
  List<dynamic> _filtered = [];
  int?          _selected;
  bool          _loading    = true;
  bool          _submitting = false;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final data = await ApiManager.fetchExistingParents();
      if (mounted) {
        setState(() { _all = data; _filtered = data; _loading = false; });
      }
    } catch (e) {
       if (mounted) setState(() => _loading = false);
    }
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _all.where((p) =>
        (p['name']  ?? '').toLowerCase().contains(q) ||
        (p['email'] ?? '').toLowerCase().contains(q) ||
        (p['phone'] ?? '').toLowerCase().contains(q)).toList();
    });
  }

  Future<void> _confirm() async {
    if (_selected == null) return;
    setState(() => _submitting = true);

    final (ok, errMsg) = await ApiManager.linkExistingParent(
      studentId: widget.studentId, parentUserId: _selected!);

    if (!mounted) return;

    if (ok) {
      Navigator.pop(context);
      await widget.onSuccess();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Parent linked successfully!'), backgroundColor: Colors.green));
    } else {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(errMsg ?? 'Failed'), backgroundColor: AppTheme.accentColor));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (_, sc) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _handle(),
            Row(children: [
              const Icon(Icons.person_search_outlined, color: AppTheme.primaryColor, size: 24),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Link Existing Parent', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('for ${widget.studentName}', style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13)),
              ]),
            ]),
            const SizedBox(height: 16),
            TextField(
              controller: _searchCtrl,
              enabled: !_submitting,
              decoration: InputDecoration(
                hintText: 'Search name, email or phone...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                  ? Center(child: Text(
                      _all.isEmpty ? 'No parent accounts exist yet.' : 'No results found.',
                      style: TextStyle(color: Colors.grey.shade500)))
                  : ListView.builder(
                      controller: sc,
                      itemCount: _filtered.length,
                      itemBuilder: (_, idx) {
                        final p = _filtered[idx];
                        final sel = _selected == p['user_id'];
                        return GestureDetector(
                          onTap: _submitting ? null : () => setState(() => _selected = p['user_id'] as int),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: sel ? AppTheme.primaryColor.withValues(alpha: 0.08) : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: sel ? AppTheme.primaryColor : Colors.grey.shade200, width: sel ? 1.5 : 1),
                            ),
                            child: Row(children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: sel ? AppTheme.primaryColor.withValues(alpha: 0.15) : Colors.grey.shade200,
                                child: Text((p['name'] ?? '?')[0].toUpperCase(),
                                    style: TextStyle(color: sel ? AppTheme.primaryColor : Colors.grey.shade600, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(p['name'] ?? '', style: TextStyle(fontWeight: FontWeight.bold,
                                    color: sel ? AppTheme.primaryColor : AppTheme.textPrimaryColor)),
                                Text(p['email'] ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor)),
                                if (p['phone'] != null)
                                  Text(p['phone'], style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                              ])),
                              if (sel) const Icon(Icons.check_circle, color: AppTheme.primaryColor),
                            ]),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: (_selected == null || _submitting) ? null : _confirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _submitting
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                  : const Text('Link Selected Parent',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// shared drag handle
Widget _handle() => Center(
      child: Container(
        width: 40, height: 4,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
      ),
    );
