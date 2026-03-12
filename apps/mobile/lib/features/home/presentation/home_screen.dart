import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:oralscan_ai/core/l10n/app_strings.dart';
import 'package:oralscan_ai/features/analysis/data/api_client.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _importing = false;
  String? _importError;

  Future<void> _importAndAnalyze() async {
    if (_importing || !mounted) return;
    setState(() => _importError = null);

    final picker = ImagePicker();
    XFile? xFile;
    try {
      xFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    } on PlatformException catch (e) {
      if (mounted) {
        final msg = '${AppStrings.photoPickerFailed} ${e.message ?? e.code}';
        setState(() => _importError = msg);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
      return;
    } on MissingPluginException catch (_) {
      if (mounted) {
        setState(() => _importError = AppStrings.importNotSupported);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text(AppStrings.importNotSupported), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
      return;
    } catch (e) {
      if (mounted) {
        final msg = '${AppStrings.couldNotOpenPicker} $e';
        setState(() => _importError = msg);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
      return;
    }

    if (xFile == null || !mounted) {
      // User cancelled or closed the picker
      return;
    }

    setState(() => _importing = true);
    try {
      final bytes = await xFile.readAsBytes();
      final api = AnalysisApiClient();
      final jobId = await api.uploadAndAnalyze(bytes);
      if (!mounted) return;
      if (jobId != null) {
        context.go('/result/$jobId');
      } else {
        setState(() => _importError = AppStrings.uploadFailedApi);
      }
    } catch (e) {
      if (mounted) {
        final msg = e is Exception ? e.toString().replaceFirst('Exception: ', '') : e.toString();
        setState(() => _importError = msg);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Scaffold(
          backgroundColor: theme.colorScheme.surface,
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: true,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                LayoutBuilder(
                                  builder: (context, _) {
                                    final w = ((MediaQuery.sizeOf(context).width - 48) * 0.55).clamp(140.0, 220.0);
                                    return SizedBox(
                                      width: w,
                                      height: w * 0.55,
                                      child: Center(
                                            child: Image.asset(
                                          'lib/features/home/presentation/assets/bucco-dentaire.png',
                                          fit: BoxFit.contain,
                                          alignment: Alignment.center,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 8),
                      
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          AppStrings.appTitle,
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            height: 1.1,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                  
                        const SizedBox(height: 32),
                        _FeatureRow(
                          icon: Icons.camera_alt_rounded,
                          title: AppStrings.guidedCapture,
                          subtitle: AppStrings.guidedCaptureSubtitle,
                        ),
                        const SizedBox(height: 16),
                        _FeatureRow(
                          icon: Icons.analytics_outlined,
                          title: AppStrings.preScreening,
                          subtitle: AppStrings.preScreeningSubtitle,
                        ),
                        const SizedBox(height: 16),
                        _FeatureRow(
                          icon: Icons.chat_bubble_outline_rounded,
                          title: AppStrings.plainLanguageResult,
                          subtitle: AppStrings.plainLanguageResultSubtitle,
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _importing ? null : () => context.push('/camera'),
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                          child: const Text(AppStrings.takePhoto),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _importing ? null : _importAndAnalyze,
                          icon: const Icon(Icons.photo_library_outlined, size: 22),
                          label: const Text(AppStrings.importImage),
                          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                        ),
                        if (_importError != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _importError!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          AppStrings.disclaimer,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_importing)
          Container(
            color: Colors.black26,
            child: const Center(
              child:               Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(AppStrings.uploadingAnalyzing, style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 28, color: theme.colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
