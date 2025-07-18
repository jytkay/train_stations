import 'package:flutter/material.dart';
import 'package:group_assignment/firestore/save_reminders.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as dev;

class EditReminderDialog extends StatefulWidget {
  final String documentId;
  final DateTime? currentTime;
  final String? currentMode;
  final List<String>? currentDays;
  final bool currentStatus;
  final bool hasReminder;
  final Map<String, dynamic>? routeDetails; // Add this for new reminders

  const EditReminderDialog({
    super.key,
    required this.documentId,
    this.currentTime,
    this.currentMode,
    this.currentDays,
    required this.currentStatus,
    required this.hasReminder,
    this.routeDetails, // Add this parameter
  });

  @override
  State<EditReminderDialog> createState() => _EditReminderDialogState();
}

class _EditReminderDialogState extends State<EditReminderDialog> {
  TimeOfDay? selectedTime;
  String reminderType = 'One Time';
  final Map<String, bool> selectedDays = {
    'Monday': false,
    'Tuesday': false,
    'Wednesday': false,
    'Thursday': false,
    'Friday': false,
    'Saturday': false,
    'Sunday': false,
  };

  bool isLoading = false;
  String? departTimeFromSteps;
  String? arriveTimeFromSteps;

  @override
  void initState() {
    super.initState();
    _initializeValues();
  }

  void _initializeValues() {
    if (widget.currentTime != null) {
      selectedTime = TimeOfDay.fromDateTime(widget.currentTime!);
    }

    if (widget.currentMode != null) {
      reminderType = widget.currentMode!;
    }

    if (widget.currentDays != null && widget.currentDays!.isNotEmpty) {
      for (final day in widget.currentDays!) {
        if (selectedDays.containsKey(day)) {
          selectedDays[day] = true;
        }
      }
    }

    // Extract departure and arrival times from route details
    _extractTimesFromRouteDetails();

    // Set default selectedTime if not editing an existing reminder
    if (widget.currentTime == null && departTimeFromSteps != null && !widget.hasReminder) {
      try {
        final parsed = DateFormat('h:mm a').parse(departTimeFromSteps!);
        final initial = DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
          parsed.hour,
          parsed.minute,
        ).subtract(const Duration(minutes: 30));
        selectedTime = TimeOfDay.fromDateTime(initial);
      } catch (e) {
        dev.log("Failed to parse departure time: $e");
      }
    }
  }

  void _extractTimesFromRouteDetails() {
    final routeDetails = widget.routeDetails;
    if (routeDetails != null) {
      final routeStepsRaw = routeDetails['routeSteps'];
      if (routeStepsRaw is List && routeStepsRaw.isNotEmpty) {
        final firstStep = routeStepsRaw.first as Map<String, dynamic>;
        final lastStep = routeStepsRaw.last as Map<String, dynamic>;

        departTimeFromSteps = firstStep['departureTime']?.toString();
        arriveTimeFromSteps = lastStep['arrivalTime']?.toString();

        dev.log("Initialized default times: $departTimeFromSteps → $arriveTimeFromSteps");
      }
    }
  }

  Future<void> _selectTime() async {
    // Ensure we have the latest route details
    if (departTimeFromSteps == null) {
      _extractTimesFromRouteDetails();
    }

    dev.log('departTimeFromSteps $departTimeFromSteps');

    // Use existing selectedTime if available, otherwise calculate from departure time
    TimeOfDay initialTime;

    if (selectedTime != null) {
      initialTime = selectedTime!;
    } else if (departTimeFromSteps != null && !widget.hasReminder) {
      // Only use departTimeFromSteps for new reminders
      try {
        // Parse the departure time (e.g., "2:30 PM")
        final parsed = DateFormat('h:mm a').parse(departTimeFromSteps!);
        final initialDateTime = DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
          parsed.hour,
          parsed.minute,
        ).subtract(const Duration(minutes: 30));
        initialTime = TimeOfDay.fromDateTime(initialDateTime);
      } catch (e) {
        // If parsing fails, fallback to now
        dev.log("Failed to parse departureTimeFromSteps: $e");
        initialTime = TimeOfDay.now();
      }
    } else {
      initialTime = TimeOfDay.now();
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null) {
      setState(() {
        selectedTime = picked;
      });
    }
  }

  void _toggleDay(String day) {
    setState(() {
      selectedDays[day] = !selectedDays[day]!;
    });
  }

  bool _isValidConfiguration() {
    if (selectedTime == null) return false;
    if (reminderType == 'Daily' || reminderType == 'Custom Days') {
      return selectedDays.values.any((v) => v);
    }
    return true;
  }

  Future<void> _saveReminder() async {
    if (!_isValidConfiguration()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a time and at least one day'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final now = DateTime.now();
      DateTime reminderDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        selectedTime!.hour,
        selectedTime!.minute,
      );

      if (reminderType == 'One Time' && reminderDateTime.isBefore(now)) {
        reminderDateTime = reminderDateTime.add(const Duration(days: 1));
      }

      final selectedDaysList = selectedDays.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();

      if (widget.hasReminder) {
        await updateAlarmDetails(
          documentId: widget.documentId,
          alarmTime: reminderDateTime,
          alarmMode: reminderType,
          isActive: widget.currentStatus,
          selectedDays: selectedDaysList,
        );

        if (mounted) {
          final snackBarFuture = ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reminder updated successfully'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          ).closed;

          await snackBarFuture;

          if (mounted) {
            Navigator.of(context).pop({
              'time': reminderDateTime,
              'mode': reminderType,
              'days': reminderType == 'One Time' ? null : selectedDaysList,
            });
          }
        }
      } else {
        if (widget.routeDetails == null) {
          throw Exception('Route details are required for new reminders');
        }

        final routeDetails = widget.routeDetails!;

        var routeSteps = routeDetails['routeSteps'] as List<Map<String, dynamic>>;
        var departTime;
        var arriveTime;

        if (routeSteps.isNotEmpty) {
          final firstStep = routeSteps.first;
          final lastStep = routeSteps.last;

          departTime = firstStep['departureTime']?.toString();
          arriveTime = lastStep['arrivalTime']?.toString();
        }

        await saveReminderToFirestore(
          userId: routeDetails['userId'] as String,
          routeId: routeDetails['routeId'] as String,
          fromStation: routeDetails['fromStation'] as String,
          toStation: routeDetails['toStation'] as String,
          departureTime: departTime as String,
          arrivalTime: arriveTime as String,
          alarmTime: reminderDateTime,
          alarmMode: reminderType,
          isActive: true,
          selectedDays: selectedDaysList,
          routeSteps: routeSteps,
        );

        if (mounted) {
          final snackBarFuture = ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reminder created successfully'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          ).closed;

          await snackBarFuture;

          if (mounted) {
            Navigator.of(context).pop({
              'saved': true,
              'time': reminderDateTime,
              'mode': reminderType,
              'days': reminderType == 'One Time' ? null : selectedDaysList,
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${widget.hasReminder ? 'update' : 'create'} reminder: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteReminder() async {
    setState(() {
      isLoading = true;
    });

    try {
      await deleteReminder(widget.documentId);

      if (mounted) {
        Navigator.of(context).pop({'delete': true});

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reminder deleted successfully'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete reminder: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Widget _buildTimeSelector() {
    String timeText;

    if (selectedTime != null && widget.hasReminder) {
      timeText = selectedTime!.format(context);
      dev.log("Default Time: " + timeText);
    } else if (departTimeFromSteps != null && !widget.hasReminder) {
      dev.log("Time found! $departTimeFromSteps");
      // Show the calculated default time for new reminders
      try {
        final cleaned = departTimeFromSteps!.replaceAll('\u202F', ' ');
        final parsed = DateFormat('h:mm a').parse(cleaned);
        final defaultTime = DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
          parsed.hour,
          parsed.minute,
        ).subtract(const Duration(minutes: 30));
        timeText = TimeOfDay.fromDateTime(defaultTime).format(context);
      } catch (e) {
        timeText = 'No time selected';
      }
    } else {
      timeText = 'No time selected';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              timeText,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          TextButton(
            onPressed: _selectTime,
            style: TextButton.styleFrom(foregroundColor: Colors.pink),
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderTypeChips() {
    const types = ['One Time', 'Daily', 'Custom Days'];

    return Wrap(
      spacing: 8,
      children: types.map((type) {
        final isSelected = reminderType == type;
        return ChoiceChip(
          label: Text(type),
          selected: isSelected,
          onSelected: (_) {
            setState(() {
              reminderType = type;
              if (reminderType == 'Daily') {
                selectedDays.updateAll((key, _) => true);
              } else if (reminderType == 'One Time') {
                selectedDays.updateAll((key, _) => false);
              }
            });
          },
          selectedColor: Colors.pink.shade200,
          backgroundColor: Colors.grey.shade200,
          checkmarkColor: Colors.white,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDaySelector() {
    if (reminderType == 'One Time') return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            const Text('Select Days',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (reminderType == 'Custom Days')
              TextButton(
                onPressed: () {
                  final allSelected = selectedDays.values.every((v) => v);
                  setState(() {
                    selectedDays.updateAll((key, _) => !allSelected);
                  });
                },
                style: TextButton.styleFrom(foregroundColor: Colors.pink),
                child: Text(
                  selectedDays.values.every((v) => v) ? 'Clear All' : 'Select All',
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: reminderType == 'Daily'
              ? Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text(
                'Every day',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          )
              : Wrap(
            spacing: 8,
            runSpacing: 4,
            children: selectedDays.entries.map((entry) {
              final day = entry.key;
              final isSelected = entry.value;
              return FilterChip(
                label: Text(day.substring(0, 3)),
                selected: isSelected,
                onSelected: (_) => _toggleDay(day),
                selectedColor: Colors.pink.shade200,
                showCheckmark: false,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.pink.shade50,
      title: Text(widget.hasReminder ? 'Edit Reminder' : 'Add Reminder'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTimeSelector(),
            const SizedBox(height: 20),
            _buildReminderTypeChips(),
            _buildDaySelector(),
          ],
        ),
      ),
      actions: [
        Row(
          children: widget.hasReminder
              ? [
            Expanded(
              child: ElevatedButton(
                onPressed: isLoading ? null : _deleteReminder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8A80),
                  foregroundColor: Colors.white,
                ),
                child: isLoading
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('Delete'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: isLoading ? null : _saveReminder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF64B5F6),
                  foregroundColor: Colors.white,
                ),
                child: isLoading
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('Edit'),
              ),
            ),
          ]
              : [
            Expanded(
              child: ElevatedButton(
                onPressed: isLoading ? null : _saveReminder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF48FB1),
                  foregroundColor: Colors.white,
                ),
                child: isLoading
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}