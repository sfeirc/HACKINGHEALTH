import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:oralscan_ai/core/l10n/app_strings.dart';
import 'package:oralscan_ai/features/analysis/data/api_client.dart';
import 'package:oralscan_ai/features/analysis/domain/job_status.dart';
import 'package:oralscan_ai/shared/widgets/app_card.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.jobId});

  final String jobId;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final _api = AnalysisApiClient();
  JobStatusResponse? _response;
  String? _error;
  Timer? _pollTimer;
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final _locationOfBirthController = TextEditingController();
  String? _selectedGender;
  bool _formSent = false;
  bool _formSending = false;
  String? _formError;

  @override
  void dispose() {
    _pollTimer?.cancel();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _dateOfBirthController.dispose();
    _locationOfBirthController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final phone = _phoneController.text.trim();
    final dateOfBirth = _dateOfBirthController.text.trim();
    final locationOfBirth = _locationOfBirthController.text.trim();
    if (firstName.isEmpty || lastName.isEmpty || phone.isEmpty || dateOfBirth.isEmpty) {
      setState(() => _formError = AppStrings.formSendFailed);
      return;
    }
    setState(() {
      _formSending = true;
      _formError = null;
    });
    final ok = await _api.submitForm(
      jobId: widget.jobId,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      dateOfBirth: dateOfBirth,
      gender: _selectedGender,
      locationOfBirth: locationOfBirth.isEmpty ? null : locationOfBirth,
    );
    if (!mounted) return;
    setState(() {
      _formSending = false;
      _formSent = ok;
      _formError = ok ? null : AppStrings.formSendFailed;
    });
  }

  @override
  void initState() {
    super.initState();
    _poll();
  }

  Future<void> _poll() async {
    final r = await _api.getJobStatus(widget.jobId);
    if (!mounted) return;
      setState(() {
      _response = r;
      _error = r == null ? AppStrings.failedToLoadResult : null;
    });
    if (r != null &&
        r.status != JobStatus.completed &&
        r.status != JobStatus.failed) {
      _pollTimer = Timer(const Duration(milliseconds: 1500), _poll);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_error != null) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          title: const Text(AppStrings.result),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => context.go('/'),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off_rounded, size: 64, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                const SizedBox(height: 20),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.failedToLoadResultHint,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: () => context.go('/camera'),
                  icon: const Icon(Icons.camera_alt_outlined, size: 20),
                  label: const Text(AppStrings.retakePhoto),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_response == null) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(title: const Text(AppStrings.result)),
        body: const Center(child: _LoadingState()),
      );
    }

    final status = _response!.status;
    if (status == JobStatus.queued || status == JobStatus.processing) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(title: const Text(AppStrings.result)),
        body: const Center(child: _LoadingState()),
      );
    }

    if (status == JobStatus.failed) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          title: const Text(AppStrings.result),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => context.go('/'),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.camera_alt_outlined, size: 64, color: theme.colorScheme.primary.withValues(alpha: 0.7)),
                const SizedBox(height: 20),
                Text(
                  AppStrings.retakePhotoTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _response!.error ?? AppStrings.retakePhotoReasonGeneric,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: () => context.go('/camera'),
                  icon: const Icon(Icons.camera_alt_outlined, size: 20),
                  label: const Text(AppStrings.retakePhoto),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final result = _response!.result;
    final explanation = _response!.explanation;

    // Completed but photo rejected (quality gate or AI says retake): show clear "retake photo" message.
    if (result != null &&
        (!result.imageQuality.usable || explanation?.retakeNeeded == true)) {
      final reasons = result.imageQuality.reasons;
      final message = reasons.isNotEmpty
          ? reasons.join(' ')
          : (explanation?.summaryText.isNotEmpty == true
              ? explanation!.summaryText
              : AppStrings.retakePhotoReasonGeneric);
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          title: const Text(AppStrings.result),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => context.go('/'),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.camera_alt_outlined, size: 64, color: theme.colorScheme.primary.withValues(alpha: 0.7)),
                const SizedBox(height: 20),
                Text(
                  AppStrings.retakePhotoTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: () => context.go('/camera'),
                  icon: const Icon(Icons.camera_alt_outlined, size: 20),
                  label: const Text(AppStrings.retakePhoto),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Success: show "Analysis complete" + form (no score/report visible to user).
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(AppStrings.result),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.analysisComplete,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.fillFormBelow,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            if (_formSent) ...[
              Icon(Icons.check_circle_rounded, size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                AppStrings.formSentSuccess,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.home_rounded, size: 20),
                label: const Text(AppStrings.backToHome),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ] else ...[
              AppCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(
                        labelText: AppStrings.firstName,
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                      enabled: !_formSending,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(
                        labelText: AppStrings.lastName,
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                      enabled: !_formSending,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: AppStrings.phone,
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      enabled: !_formSending,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _dateOfBirthController,
                      decoration: const InputDecoration(
                        labelText: AppStrings.dateOfBirth,
                        border: OutlineInputBorder(),
                        hintText: 'JJ/MM/AAAA',
                      ),
                      keyboardType: TextInputType.datetime,
                      enabled: !_formSending,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedGender,
                      decoration: const InputDecoration(
                        labelText: AppStrings.gender,
                        border: OutlineInputBorder(),
                      ),
                      hint: const Text('Choisir'),
                      items: const [
                        DropdownMenuItem(value: AppStrings.genderMale, child: Text(AppStrings.genderMale)),
                        DropdownMenuItem(value: AppStrings.genderFemale, child: Text(AppStrings.genderFemale)),
                        DropdownMenuItem(value: AppStrings.genderOther, child: Text(AppStrings.genderOther)),
                      ],
                      onChanged: _formSending ? null : (v) => setState(() => _selectedGender = v),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _locationOfBirthController,
                      decoration: const InputDecoration(
                        labelText: AppStrings.locationOfBirth,
                        border: OutlineInputBorder(),
                        hintText: 'Ville ou pays',
                      ),
                      textCapitalization: TextCapitalization.words,
                      enabled: !_formSending,
                    ),
                    if (_formError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _formError!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _formSending ? null : _submitForm,
                      icon: _formSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, size: 20),
                      label: Text(_formSending ? AppStrings.sending : AppStrings.send),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 44,
          height: 44,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
        const SizedBox(height: 20),
        Text(
          AppStrings.analyzingYourImage,
          style: t.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          AppStrings.usuallyTakesFewSeconds,
          style: t.textTheme.bodySmall,
        ),
      ],
    );
  }
}
