import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/session.dart';
import '../../services/location_service.dart';
import '../../services/session_service.dart';
import '../../theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_button.dart';

// ── Saved Location model ──────────────────────────────────────────────────────

class SavedLocation {
  final String id;
  String name;
  final double lat;
  final double lng;

  SavedLocation({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'lat': lat,
    'lng': lng,
  };

  factory SavedLocation.fromJson(Map<String, dynamic> json) => SavedLocation(
    id: json['id'] as String,
    name: json['name'] as String,
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
  );
}

// ── Saved Locations Service (shared_preferences) ──────────────────────────────

class SavedLocationsService {
  static const _key = 'saved_locations';

  static Future<List<SavedLocation>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => SavedLocation.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<SavedLocation> locations) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(locations.map((l) => l.toJson()).toList()),
    );
  }

  static Future<void> add(SavedLocation location) async {
    final list = await load();
    list.add(location);
    await save(list);
  }

  static Future<void> update(SavedLocation updated) async {
    final list = await load();
    final idx = list.indexWhere((l) => l.id == updated.id);
    if (idx != -1) {
      list[idx] = updated;
      await save(list);
    }
  }

  static Future<void> remove(String id) async {
    final list = await load();
    list.removeWhere((l) => l.id == id);
    await save(list);
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class AdminCreateSessionScreen extends StatefulWidget {
  const AdminCreateSessionScreen({super.key});
  @override
  State<AdminCreateSessionScreen> createState() =>
      _AdminCreateSessionScreenState();
}

class _AdminCreateSessionScreenState extends State<AdminCreateSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _radiusCtrl = TextEditingController(text: '100');
  DateTime _startDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  DateTime _endDate = DateTime.now().add(const Duration(hours: 2));
  TimeOfDay _endTime = TimeOfDay.fromDateTime(
    DateTime.now().add(const Duration(hours: 2)),
  );
  bool _loading = false;
  bool _detectingLocation = false;
  String? _errorMessage;

  List<SavedLocation> _savedLocations = [];
  bool _savedLocationsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadSavedLocations();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _radiusCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSavedLocations() async {
    final list = await SavedLocationsService.load();
    if (mounted) {
      setState(() {
        _savedLocations = list;
        _savedLocationsLoaded = true;
      });
    }
  }

  // ── Coordinate helpers ─────────────────────────────────────────────────────

  void _fillCoords(double lat, double lng) {
    setState(() {
      _latCtrl.text = lat.toStringAsFixed(6);
      _lngCtrl.text = lng.toStringAsFixed(6);
    });
  }

  // ── Date / Time pickers ────────────────────────────────────────────────────

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  // ── GPS detection ──────────────────────────────────────────────────────────

  Future<void> _detectCurrentLocation() async {
    setState(() {
      _detectingLocation = true;
      _errorMessage = null;
    });
    final result = await LocationService.getCurrentPosition();
    if (!mounted) return;
    setState(() {
      _detectingLocation = false;
    });
    if (result.isSuccess) {
      final pos = result.position!;
      _fillCoords(pos.latitude, pos.longitude);
      _showSnack('Successfully detected current coordinates');
      // Ask if admin wants to save this location
      _offerToSaveLocation(pos.latitude, pos.longitude);
    } else {
      setState(() {
        _errorMessage = result.error ?? 'Could not detect location';
      });
    }
  }

  // ── Map picker ─────────────────────────────────────────────────────────────

  Future<void> _openMapPicker() async {
    LatLng center = const LatLng(-6.2088, 106.8456); // Jakarta default

    final curLat = double.tryParse(_latCtrl.text);
    final curLng = double.tryParse(_lngCtrl.text);
    if (curLat != null && curLng != null) {
      center = LatLng(curLat, curLng);
    }

    final result = await showDialog<LatLng>(
      context: context,
      builder: (ctx) => _MapPickerDialog(initialCenter: center),
    );

    if (result != null) {
      _fillCoords(result.latitude, result.longitude);
      if (mounted) {
        _offerToSaveLocation(result.latitude, result.longitude);
      }
    }
  }

  // ── Save location prompt ───────────────────────────────────────────────────

  void _offerToSaveLocation(double lat, double lng) {
    showDialog(
      context: context,
      builder: (ctx) => _SaveLocationDialog(lat: lat, lng: lng),
    ).then((saved) {
      if (saved != null && mounted) {
        SavedLocationsService.add(saved).then((_) => _loadSavedLocations());
      }
    });
  }

  // ── Saved locations dialog ─────────────────────────────────────────────────

  void _openSavedLocations() {
    showDialog(
      context: context,
      builder: (ctx) => _SavedLocationsDialog(
        locations: _savedLocations,
        onSelect: (loc) {
          Navigator.pop(ctx);
          _fillCoords(loc.lat, loc.lng);
          _showSnack('Applied saved location: ${loc.name}');
        },
        onDelete: (loc) async {
          await SavedLocationsService.remove(loc.id);
          await _loadSavedLocations();
          if (ctx.mounted) Navigator.pop(ctx);
          if (mounted) {
            _openSavedLocations(); // reopen with updated list
          }
        },
        onEdit: (loc, newName) async {
          loc.name = newName;
          await SavedLocationsService.update(loc);
          await _loadSavedLocations();
          if (ctx.mounted) Navigator.pop(ctx);
          if (mounted) {
            _openSavedLocations(); // reopen with updated list
          }
        },
      ),
    );
  }

  // ── Save session ───────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final lat = double.tryParse(_latCtrl.text);
    final lng = double.tryParse(_lngCtrl.text);
    final radius = int.tryParse(_radiusCtrl.text);
    if (lat == null || lng == null) {
      setState(() => _errorMessage = 'Please enter valid coordinates');
      return;
    }
    if (radius == null || radius <= 0) {
      setState(() => _errorMessage = 'Please enter a valid radius (> 0)');
      return;
    }
    final startDateTime = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _startTime.hour,
      _startTime.minute,
    );
    final endDateTime = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
      _endTime.hour,
      _endTime.minute,
    );
    if (endDateTime.isBefore(startDateTime)) {
      setState(() => _errorMessage = 'End time must be after start time');
      return;
    }
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final session = Session(
        id: '', // Generated by DB
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        targetLat: lat,
        targetLng: lng,
        radiusMeters: radius,
        startTime: startDateTime,
        endTime: endDateTime,
        isActive: true,
        createdAt: DateTime.now(),
      );
      await SessionService.createSession(session);
      if (!mounted) return;
      _showSnack('Session created successfully');
      context.go('/admin/sessions');
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to create session: $e';
          _loading = false;
        });
      }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: TextStyle(color: Colors.white)),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Attendance Session'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin/sessions'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create Session',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(
                    'Set the parameters for attendance check-in',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  if (_errorMessage != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'General Information',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Session Name',
                            hintText: 'e.g., Town Hall Q2 2026',
                            prefixIcon: Icon(Icons.title),
                          ),
                          validator: (val) => val == null || val.trim().isEmpty
                              ? 'Name is required'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Description (Optional)',
                            hintText:
                                'Provide details about this attendance session',
                            prefixIcon: Icon(Icons.description),
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Geofencing Card ─────────────────────────────────────
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title row with saved locations count badge
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Location Settings',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                            if (_savedLocationsLoaded &&
                                _savedLocations.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  '${_savedLocations.length} saved',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Action buttons row
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            // Detect GPS
                            TextButton.icon(
                              onPressed: _detectingLocation
                                  ? null
                                  : _detectCurrentLocation,
                              icon: _detectingLocation
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.secondary,
                                      ),
                                    )
                                  : const Icon(Icons.my_location, size: 18),
                              label: const Text('Use Current GPS'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.secondary,
                              ),
                            ),
                            // Map picker
                            TextButton.icon(
                              onPressed: _openMapPicker,
                              icon: const Icon(Icons.map_outlined, size: 18),
                              label: const Text('Pick on Map'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                              ),
                            ),
                            // Saved locations
                            TextButton.icon(
                              onPressed: _savedLocationsLoaded
                                  ? _openSavedLocations
                                  : null,
                              icon: const Icon(
                                Icons.bookmark_outlined,
                                size: 18,
                              ),
                              label: Text(
                                _savedLocations.isEmpty
                                    ? 'Saved Locations'
                                    : 'Saved Locations (${_savedLocations.length})',
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.warning,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Lat / Lng fields
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _latCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Latitude',
                                  hintText: '-6.200000',
                                  prefixIcon: Icon(Icons.location_on),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Required';
                                  }
                                  if (double.tryParse(val) == null) {
                                    return 'Invalid number';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _lngCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Longitude',
                                  hintText: '106.816666',
                                  prefixIcon: Icon(Icons.location_on),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Required';
                                  }
                                  if (double.tryParse(val) == null) {
                                    return 'Invalid number';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _radiusCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Allowed Radius (meters)',
                            hintText: '100',
                            prefixIcon: Icon(Icons.radar),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Required';
                            }
                            final intVal = int.tryParse(val);
                            if (intVal == null || intVal <= 0) {
                              return 'Must be a positive integer';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Schedule ─────────────────────────────────────────────
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Schedule (Time Range)',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Start Date & Time',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () =>
                                              _selectDate(context, true),
                                          icon: const Icon(
                                            Icons.calendar_today,
                                            size: 16,
                                          ),
                                          label: Text(
                                            dateFormat.format(_startDate),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () =>
                                              _selectTime(context, true),
                                          icon: const Icon(
                                            Icons.access_time,
                                            size: 16,
                                          ),
                                          label: Text(
                                            _startTime.format(context),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'End Date & Time',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () =>
                                              _selectDate(context, false),
                                          icon: const Icon(
                                            Icons.calendar_today,
                                            size: 16,
                                          ),
                                          label: Text(
                                            dateFormat.format(_endDate),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () =>
                                              _selectTime(context, false),
                                          icon: const Icon(
                                            Icons.access_time,
                                            size: 16,
                                          ),
                                          label: Text(_endTime.format(context)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: _loading
                            ? null
                            : () => context.go('/admin/sessions'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 16),
                      GradientButton(
                        label: 'Create Session',
                        icon: Icons.check,
                        width: 180,
                        isLoading: _loading,
                        onPressed: _save,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Save Location Dialog ──────────────────────────────────────────────────────

class _SaveLocationDialog extends StatefulWidget {
  final double lat;
  final double lng;

  const _SaveLocationDialog({required this.lat, required this.lng});

  @override
  State<_SaveLocationDialog> createState() => _SaveLocationDialogState();
}

class _SaveLocationDialogState extends State<_SaveLocationDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.bookmark_add, color: AppColors.primary),
          SizedBox(width: 10),
          Text('Save Location'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Coordinates: ${widget.lat.toStringAsFixed(6)}, ${widget.lng.toStringAsFixed(6)}',
            style: const TextStyle(
              color: AppColors.primary,
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Location Name',
              hintText: 'e.g., Head Office, Warehouse A',
              prefixIcon: Icon(Icons.label_outline),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Skip'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            final name = _ctrl.text.trim();
            if (name.isEmpty) return;
            final saved = SavedLocation(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: name,
              lat: widget.lat,
              lng: widget.lng,
            );
            Navigator.pop(context, saved);
          },
          icon: const Icon(Icons.save),
          label: const Text('Save'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

// ── Saved Locations Dialog ────────────────────────────────────────────────────

class _SavedLocationsDialog extends StatelessWidget {
  final List<SavedLocation> locations;
  final void Function(SavedLocation) onSelect;
  final void Function(SavedLocation) onDelete;
  final void Function(SavedLocation, String) onEdit;

  const _SavedLocationsDialog({
    required this.locations,
    required this.onSelect,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  const Icon(Icons.bookmark, color: AppColors.primary),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Saved Locations',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Text(
                'Tap a location to apply it. Use the icons to edit or delete.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
            const Divider(color: Colors.white12),

            // Location list
            if (locations.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.bookmark_border, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text(
                      'No saved locations yet.\nUse GPS or map picker to detect a location,\nthen save it for quick reuse.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 380),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: locations.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: Colors.white10),
                  itemBuilder: (ctx, i) {
                    final loc = locations[i];
                    return ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.location_pin,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        loc.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${loc.lat.toStringAsFixed(6)}, ${loc.lng.toStringAsFixed(6)}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: AppColors.error,
                        ),
                        tooltip: 'Delete',
                        onPressed: () => onDelete(loc),
                      ),
                      onTap: () => onSelect(loc),
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Map Picker Dialog ─────────────────────────────────────────────────────────

class _MapPickerDialog extends StatefulWidget {
  final LatLng initialCenter;

  const _MapPickerDialog({required this.initialCenter});

  @override
  State<_MapPickerDialog> createState() => _MapPickerDialogState();
}

class _MapPickerDialogState extends State<_MapPickerDialog> {
  late LatLng _selectedPoint;
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _selectedPoint = widget.initialCenter;
    _mapController = MapController();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 700,
        height: 520,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  const Icon(Icons.map_outlined, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pick Location on Map',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Text(
                'Tap anywhere on the map to set the geofence center.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[400]),
              ),
            ),
            const Divider(color: Colors.white12),

            // Map
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(0),
                ),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: widget.initialCenter,
                    initialZoom: 15,
                    onTap: (tapPosition, point) {
                      setState(() => _selectedPoint = point);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.atvara.app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _selectedPoint,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.location_pin,
                            color: AppColors.error,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Coordinate display + confirm
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selected Coordinates',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[400]),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_selectedPoint.latitude.toStringAsFixed(6)}, '
                          '${_selectedPoint.longitude.toStringAsFixed(6)}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, _selectedPoint),
                    icon: const Icon(Icons.check),
                    label: const Text('Use This Location'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
