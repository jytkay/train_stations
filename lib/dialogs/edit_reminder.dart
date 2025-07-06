import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:group_assignment/firestore/save_reminders.dart';

class EditReminderDialog extends StatefulWidget {
  final String documentId;
  final DateTime? currentTime;
  final String? currentMode;
  final List<String>? currentDays;
  final bool currentStatus;

  const EditReminderDialog({
    super.key,
    required this.documentId,
    this.currentTime,
    this.currentMode,
    this.currentDays,
    required this.currentStatus,
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
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? TimeOfDay.now(),
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
      return selectedDays.values.any((isSelected) => isSelected);
    }
    return true;
  }

  Future<void> _saveReminder() async {
    if (!_isValidConfiguration()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a time and at least one day'),
          backgroundColor: Colors.orange,
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

      await updateAlarmDetails(
        documentId: widget.documentId,
        alarmTime: reminderDateTime,
        alarmMode: reminderType,
        isActive: widget.currentStatus,
      );

      if (mounted) {
        Navigator.of(context).pop({
          'time': reminderDateTime,
          'mode': reminderType,
          'days': reminderType == 'One Time' ? null : selectedDaysList,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reminder updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update reminder: $e'),
            backgroundColor: Colors.red,
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
              selectedTime != null
                  ? selectedTime!.format(context)
                  : 'No time selected',
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
                checkmarkColor: Colors.white,
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
      title: const Text('Edit Reminder'),
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
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop({'delete': true});
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF8A80),
            foregroundColor: Colors.white,
          ),
          child: const Text('Delete'),
        ),
        ElevatedButton(
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
      ],
    );
  }
}
