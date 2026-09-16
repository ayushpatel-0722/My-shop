import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes/app_router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/models/employee.dart';
import '../../../core/services/auth_session.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/widgets/modern_button.dart';
import '../../../core/widgets/modern_card.dart';

/// Screen for creating and editing an Employee (Section 6.3 & 17.1).
///
/// Features:
/// - Create mode: fresh form, auto-assigned companyId from session.
/// - Edit mode: pre-filled fields, preserves employee ID.
/// - Required fields validation:
///   - `name`: Full name of staff member.
///   - `email`: Login email.
///   - `password`: Required on create, optional on update.
///   - `role`: Designation (Picker, Manufacturer, Manager, Dispatcher, etc.).
///   - `gender`: male | female | other.
///   - `dob`: Date of birth.
///   - `address`: Residential address.
///   - `details`: Notes, emergency contact, qualifications.
///   - `salary` & `salaryType`: Monthly or yearly compensation.
///   - `shiftActive`: Gates login to scheduled hours.
///   - `permissions`: Granular map (canPack, canDispatch, canManageInventory, canViewReports).
///   - `companyId`: Auto-assigned from admin session, read-only.
class AdminAddEmployeeScreen extends StatefulWidget {
  final Employee? employee;
  final String? employeeId;

  const AdminAddEmployeeScreen({
    super.key,
    this.employee,
    this.employeeId,
  });

  @override
  State<AdminAddEmployeeScreen> createState() => _AdminAddEmployeeScreenState();
}

class _AdminAddEmployeeScreenState extends State<AdminAddEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _detailsCtrl = TextEditingController();
  final _salaryCtrl = TextEditingController();

  // State values
  String _companyId = '';
  String _companyName = '';
  String _role = 'Picker';
  String _gender = 'male';
  DateTime? _selectedDob;
  String _salaryType = 'monthly'; // 'monthly' | 'yearly'
  bool _shiftActive = true;
  bool _isSaving = false;
  bool _isLoadingEmployee = false;
  String? _loadedEmployeeId;

  // Permissions map
  bool _canPack = true;
  bool _canDispatch = false;
  bool _canManageInventory = false;
  bool _canViewReports = false;

  static const List<String> _roles = [
    'Picker',
    'Manufacturer',
    'Manager',
    'Dispatcher',
    'Cashier',
    'Supervisor',
    'Quality Inspector',
  ];

  bool get isEditMode => widget.employee != null || widget.employeeId != null;

  @override
  void initState() {
    super.initState();
    final sessionCompanyId = AuthSession.currentUser?.companyId ?? '';
    final sessionCompanyName = AuthSession.currentUser?.companyName ?? '';
    _companyId = sessionCompanyId;
    _companyName = sessionCompanyName;

    if (_companyName.isEmpty && _companyId.isNotEmpty) {
      _loadCompanyName(_companyId);
    }

    if (widget.employee != null) {
      _initFromEmployee(widget.employee!);
    } else if (widget.employeeId != null && widget.employeeId!.isNotEmpty) {
      _loadEmployeeById(widget.employeeId!);
    }
  }

  Future<void> _loadCompanyName(String cid) async {
    try {
      final comp = await repo.company(cid);
      if (comp != null && comp.name.isNotEmpty && mounted) {
        setState(() => _companyName = comp.name);
      }
    } catch (_) {}
  }

  void _initFromEmployee(Employee emp) {
    _loadedEmployeeId = emp.id;
    _nameCtrl.text = emp.name;
    _emailCtrl.text = emp.email;
    _addressCtrl.text = emp.address;
    _detailsCtrl.text = emp.details;
    _salaryCtrl.text = emp.salary > 0 ? emp.salary.toStringAsFixed(0) : '';
    _role = emp.role.isNotEmpty ? emp.role : 'Picker';
    _gender = (emp.gender.isNotEmpty) ? emp.gender.toLowerCase() : 'male';
    _salaryType = emp.salaryType.isNotEmpty ? emp.salaryType : 'monthly';
    _shiftActive = emp.shiftActive;

    if (emp.dob != null && emp.dob!.isNotEmpty) {
      try {
        _selectedDob = DateTime.tryParse(emp.dob!);
      } catch (_) {}
    }

    _canPack = emp.permissions['canPack'] ?? false;
    _canDispatch = emp.permissions['canDispatch'] ?? false;
    _canManageInventory = emp.permissions['canManageInventory'] ?? false;
    _canViewReports = emp.permissions['canViewReports'] ?? false;

    if (emp.companyId.isNotEmpty) {
      _companyId = emp.companyId;
    }
  }

  Future<void> _loadEmployeeById(String id) async {
    setState(() => _isLoadingEmployee = true);
    try {
      final emp = await repo.employee(id, companyId: _companyId);
      if (emp != null && mounted) {
        _initFromEmployee(emp);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingEmployee = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _addressCtrl.dispose();
    _detailsCtrl.dispose();
    _salaryCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(now.year - 22, now.month, now.day),
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year - 14, now.month, now.day),
    );
    if (picked != null) {
      setState(() => _selectedDob = picked);
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_companyId.isEmpty) {
      final sessionCompany = AuthSession.currentUser?.companyId ?? '';
      if (sessionCompany.isNotEmpty) {
        _companyId = sessionCompany;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No company scope found for current admin.')),
        );
        return;
      }
    }

    final empId = _loadedEmployeeId ?? widget.employee?.id ?? widget.employeeId ?? '';

    setState(() => _isSaving = true);

    try {
      final parsedSalary = double.tryParse(_salaryCtrl.text.trim()) ?? 0.0;
      final dobStr = _selectedDob != null
          ? '${_selectedDob!.year.toString().padLeft(4, '0')}-${_selectedDob!.month.toString().padLeft(2, '0')}-${_selectedDob!.day.toString().padLeft(2, '0')}'
          : null;

      final emp = Employee(
        id: empId,
        companyId: _companyId,
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        details: _detailsCtrl.text.trim(),
        role: _role,
        gender: _gender,
        dob: dobStr,
        salary: parsedSalary,
        salaryType: _salaryType,
        shiftActive: _shiftActive,
        createdBy: AuthSession.currentUser?.id ?? '',
        permissions: {
          'canPack': _canPack,
          'canDispatch': _canDispatch,
          'canManageInventory': _canManageInventory,
          'canViewReports': _canViewReports,
        },
      );

      if (isEditMode && empId.isNotEmpty) {
        await repo.saveEmployee(emp);
      } else {
        final password = _passwordCtrl.text.trim();
        await repo.createEmployeeAccount(emp, password: password);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditMode
                ? 'Employee "${emp.name}" updated successfully!'
                : 'Employee "${emp.name}" provisioned successfully!',
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );

      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.adminEmployees);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save employee: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoadingEmployee) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading Employee...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? 'Edit Employee' : 'Provision Employee'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.adminEmployees);
            }
          },
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                // Header & Read-only Company Scope Pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditMode ? 'Employee Profile' : 'Staff Provisioning',
                            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Manage staff account, designation, salary, and operational access.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.store, size: 16, color: theme.colorScheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            _companyName.isNotEmpty
                                ? _companyName
                                : (_companyId.isNotEmpty
                                    ? 'Company Scope'
                                    : 'Global Scope'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Card 1: Account & Profile Information
                ModernCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person_outline, color: theme.colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Basic Information',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Full Name *',
                          hintText: 'e.g. Ramesh Kumar',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Full name is required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Login Email *',
                          hintText: 'e.g. ramesh@company.com',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Email is required';
                          if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      if (!isEditMode) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Initial Password *',
                            hintText: 'Minimum 6 characters',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          validator: (v) {
                            if (!isEditMode && (v == null || v.trim().length < 6)) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _roles.contains(_role) ? _role : _roles.first,
                        decoration: const InputDecoration(
                          labelText: 'Designation / Role *',
                          prefixIcon: Icon(Icons.work_outline),
                        ),
                        items: _roles.map((r) {
                          return DropdownMenuItem(value: r, child: Text(r));
                        }).toList(),
                        onChanged: (v) => setState(() => _role = v ?? 'Picker'),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Gender',
                        style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'male', label: Text('Male'), icon: Icon(Icons.male, size: 18)),
                            ButtonSegment(value: 'female', label: Text('Female'), icon: Icon(Icons.female, size: 18)),
                            ButtonSegment(value: 'other', label: Text('Other'), icon: Icon(Icons.person, size: 18)),
                          ],
                          selected: {_gender},
                          onSelectionChanged: (set) => setState(() => _gender = set.first),
                        ),
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date of Birth',
                            prefixIcon: Icon(Icons.cake_outlined),
                            suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                          ),
                          child: Text(
                            _selectedDob != null
                                ? '${_selectedDob!.day.toString().padLeft(2, '0')}/${_selectedDob!.month.toString().padLeft(2, '0')}/${_selectedDob!.year}'
                                : 'Select Date of Birth',
                            style: TextStyle(
                              color: _selectedDob != null
                                  ? (isDark ? Colors.white : Colors.black87)
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _addressCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Residential Address',
                          hintText: 'Street, area, city, pincode...',
                          prefixIcon: Icon(Icons.home_outlined),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _detailsCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Notes & Qualifications',
                          hintText: 'Emergency contact, certifications, qualifications...',
                          prefixIcon: Icon(Icons.notes_outlined),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Card 2: Compensation / Salary (Monthly or Yearly)
                ModernCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.currency_rupee, color: theme.colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Compensation & Salary',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Define staff compensation package and payment frequency.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _salaryCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Salary Amount (₹)',
                          hintText: 'e.g. 25000',
                          prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Salary Frequency',
                        style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'monthly',
                              label: Text('Monthly (₹/month)'),
                              icon: Icon(Icons.calendar_month_outlined, size: 18),
                            ),
                            ButtonSegment(
                              value: 'yearly',
                              label: Text('Yearly / CTC (₹/year)'),
                              icon: Icon(Icons.date_range_outlined, size: 18),
                            ),
                          ],
                          selected: {_salaryType},
                          onSelectionChanged: (set) => setState(() => _salaryType = set.first),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Card 3: Shift & Work Schedule Controls
                ModernCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.schedule, color: theme.colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Shift & Work Status',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Shift Active'),
                        subtitle: Text(
                          'Gates login to scheduled working hours. When disabled, the employee cannot log into the mobile app.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                          ),
                        ),
                        value: _shiftActive,
                        onChanged: (v) => setState(() => _shiftActive = v),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Card 4: Granular Operational Permissions
                ModernCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.security_outlined, color: theme.colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Operational Permissions',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Assign workflow responsibilities. Note: Staff permissions never include manual order-status changes.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _canPack,
                        title: const Text('Order Packing (canPack)'),
                        subtitle: const Text('Access packing hub to verify items and mark orders as packed.', style: TextStyle(fontSize: 12)),
                        onChanged: (v) => setState(() => _canPack = v ?? false),
                      ),
                      const Divider(height: 8),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _canDispatch,
                        title: const Text('Order Dispatch (canDispatch)'),
                        subtitle: const Text('Assign delivery riders and dispatch orders for fulfillment.', style: TextStyle(fontSize: 12)),
                        onChanged: (v) => setState(() => _canDispatch = v ?? false),
                      ),
                      const Divider(height: 8),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _canManageInventory,
                        title: const Text('Inventory Management (canManageInventory)'),
                        subtitle: const Text('View and update stock counts and warehouse alerts.', style: TextStyle(fontSize: 12)),
                        onChanged: (v) => setState(() => _canManageInventory = v ?? false),
                      ),
                      const Divider(height: 8),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _canViewReports,
                        title: const Text('Reports & Analytics (canViewReports)'),
                        subtitle: const Text('View daily employee activity and operations logs.', style: TextStyle(fontSize: 12)),
                        onChanged: (v) => setState(() => _canViewReports = v ?? false),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Save Action Button
                ModernButton(
                  text: isEditMode ? 'Save Changes' : 'Provision Employee Account',
                  icon: const Icon(Icons.check, size: 20),
                  isLoading: _isSaving,
                  height: 52,
                  onPressed: _isSaving ? null : _handleSave,
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}
