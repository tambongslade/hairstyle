import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_locale.dart';
import '../../models/hairstyle_catalog.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';

enum _UploadStatus { pending, uploading, done, error }

class StyleMigrationScreen extends StatefulWidget {
  const StyleMigrationScreen({super.key});

  @override
  State<StyleMigrationScreen> createState() => _StyleMigrationScreenState();
}

class _StyleMigrationScreenState extends State<StyleMigrationScreen> {
  final List<HairStyle> _styles = HairStyleCatalog.allStyles;
  late List<_UploadStatus> _statuses;
  late List<String> _errorMessages;
  bool _isUploading = false;
  int _completedCount = 0;
  int _failedCount = 0;

  @override
  void initState() {
    super.initState();
    _statuses = List.filled(_styles.length, _UploadStatus.pending);
    _errorMessages = List.filled(_styles.length, '');
  }

  String _genderString(Gender gender) {
    return gender == Gender.women ? 'women' : 'men';
  }

  String _categoryString(StyleCategory category) {
    switch (category) {
      case StyleCategory.wigs:
        return 'wigs';
      case StyleCategory.braids:
        return 'braids';
      case StyleCategory.locs:
        return 'locs';
      case StyleCategory.curls:
        return 'curls';
      case StyleCategory.fades:
        return 'fades';
      case StyleCategory.all:
        return 'all';
    }
  }

  String _cleanPrice(String price) {
    return price.replaceAll(',', '');
  }

  Future<void> _uploadStyle(int index) async {
    final style = _styles[index];
    debugPrint('[Sync] [$index/${_styles.length}] Starting upload: ${style.name}');
    debugPrint('[Sync]   Asset: ${style.assetPath}');
    debugPrint('[Sync]   Gender: ${_genderString(style.gender)}, Category: ${_categoryString(style.category)}, Price: ${_cleanPrice(style.price)}');
    setState(() {
      _statuses[index] = _UploadStatus.uploading;
    });

    try {
      // Load asset bytes
      debugPrint('[Sync]   Loading asset bytes...');
      final byteData = await rootBundle.load(style.assetPath);
      final bytes = byteData.buffer.asUint8List();
      debugPrint('[Sync]   Asset loaded: ${(bytes.length / 1024).toStringAsFixed(1)} KB');

      final ext = style.asset.contains('.') ? style.asset.split('.').last : 'png';
      final filename = 'style_upload_$index.$ext';

      // Upload via API
      debugPrint('[Sync]   Uploading to /admin/catalog/styles...');
      final fields = {
        'name': style.name,
        'nameKey': style.nameKey,
        'price': _cleanPrice(style.price),
        'gender': _genderString(style.gender),
        'category': _categoryString(style.category),
        'description': style.description,
        'isFeatured': 'false',
        'isActive': 'true',
      };
      debugPrint('[Sync]   Fields: $fields');

      final response = await ApiClient.instance.uploadMultipart(
        '/admin/catalog/styles',
        bytes: bytes,
        filename: filename,
        fieldName: 'image',
        fields: fields,
      );
      debugPrint('[Sync]   Upload SUCCESS: $response');

      if (!mounted) return;
      setState(() {
        _statuses[index] = _UploadStatus.done;
        _completedCount++;
      });
      debugPrint('[Sync]   Done ($_completedCount/${_styles.length})');
    } catch (e, stackTrace) {
      debugPrint('[Sync]   UPLOAD FAILED: $e');
      debugPrint('[Sync]   Stack: $stackTrace');
      if (!mounted) return;
      setState(() {
        _statuses[index] = _UploadStatus.error;
        _errorMessages[index] = e.toString();
        _failedCount++;
      });
    }
  }

  Future<void> _uploadAll() async {
    if (_isUploading) return;

    setState(() {
      _isUploading = true;
      _completedCount = 0;
      _failedCount = 0;
      // Reset all statuses to pending
      for (int i = 0; i < _statuses.length; i++) {
        _statuses[i] = _UploadStatus.pending;
        _errorMessages[i] = '';
      }
    });

    for (int i = 0; i < _styles.length; i++) {
      if (!mounted) return;
      await _uploadStyle(i);
    }

    if (!mounted) return;
    setState(() {
      _isUploading = false;
    });
  }

  Future<void> _retryFailed() async {
    if (_isUploading) return;

    setState(() {
      _isUploading = true;
      _failedCount = 0;
    });

    for (int i = 0; i < _styles.length; i++) {
      if (!mounted) return;
      if (_statuses[i] == _UploadStatus.error) {
        _errorMessages[i] = '';
        await _uploadStyle(i);
      }
    }

    if (!mounted) return;
    setState(() {
      _isUploading = false;
    });
  }

  int get _doneCount => _statuses.where((s) => s == _UploadStatus.done).length;
  int get _errorCount => _statuses.where((s) => s == _UploadStatus.error).length;
  bool get _hasErrors => _errorCount > 0;
  bool get _allDone => _doneCount == _styles.length;

  @override
  Widget build(BuildContext context) {
    final totalStyles = _styles.length;
    final progress = totalStyles > 0 ? _doneCount / totalStyles : 0.0;

    return Scaffold(
      backgroundColor: AppTheme.getBgPrimary(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppTheme.getTextPrimary(context), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          tr('syncStyles'),
          style: AppTheme.displayFont.copyWith(
            fontSize: 20,
            color: AppTheme.getTextPrimary(context),
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Summary header
          _buildSummaryCard(context, totalStyles, progress),
          const SizedBox(height: 12),
          // Action buttons
          _buildActionButtons(context),
          const SizedBox(height: 12),
          // Style list
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: totalStyles,
              itemBuilder: (context, index) => _buildStyleItem(context, index),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, int totalStyles, double progress) {
    String statusText;
    if (_allDone) {
      statusText = tr('uploadComplete');
    } else if (_isUploading) {
      statusText = tr('uploadProgress');
    } else if (_hasErrors && !_isUploading) {
      statusText = '$_errorCount ${tr('failed')}';
    } else {
      statusText = '$totalStyles ${tr('stylesReady')}';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.getGold(context).withValues(alpha: 0.12),
            AppTheme.getGold(context).withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.getGold(context).withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppTheme.getGold(context), AppTheme.teal]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.cloud_upload_outlined, color: AppTheme.getBgPrimary(context), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.getTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_doneCount / $totalStyles ${tr('uploaded')}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (_allDone)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.check_circle, color: AppTheme.accentGreen, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 14),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppTheme.getBgGlass(context),
              valueColor: AlwaysStoppedAnimation<Color>(
                _hasErrors && !_isUploading
                    ? AppTheme.accentRed
                    : AppTheme.getGold(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Upload All button
          Expanded(
            child: GestureDetector(
              onTap: _isUploading ? null : _uploadAll,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: _isUploading
                      ? null
                      : LinearGradient(
                          colors: [AppTheme.getGold(context), AppTheme.teal],
                        ),
                  color: _isUploading ? AppTheme.getBgGlass(context) : null,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _isUploading ? null : AppTheme.goldShadow,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isUploading)
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.getTextSecondary(context),
                          ),
                        ),
                      )
                    else
                      Icon(Icons.cloud_upload, size: 18, color: AppTheme.getBgPrimary(context)),
                    const SizedBox(width: 8),
                    Text(
                      _isUploading ? tr('uploadProgress') : tr('uploadAll'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _isUploading
                            ? AppTheme.getTextSecondary(context)
                            : AppTheme.getBgPrimary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Retry Failed button (only if there are errors and not uploading)
          if (_hasErrors && !_isUploading) ...[
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: _retryFailed,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.accentRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.refresh, size: 18, color: AppTheme.accentRed),
                      const SizedBox(width: 8),
                      Text(
                        tr('retryFailed'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentRed,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStyleItem(BuildContext context, int index) {
    final style = _styles[index];
    final status = _statuses[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.getBgGlass(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: status == _UploadStatus.done
              ? AppTheme.accentGreen.withValues(alpha: 0.3)
              : status == _UploadStatus.error
                  ? AppTheme.accentRed.withValues(alpha: 0.3)
                  : AppTheme.getBorder(context),
        ),
      ),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              style.assetPath,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.getBgGlassStrong(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.image, size: 20, color: AppTheme.getTextTertiary(context)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  style.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.getTextPrimary(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    _buildTag(
                      context,
                      _genderString(style.gender).toUpperCase(),
                      style.gender == Gender.women
                          ? AppTheme.accentBlue
                          : AppTheme.teal,
                    ),
                    const SizedBox(width: 6),
                    _buildTag(
                      context,
                      _categoryString(style.category).toUpperCase(),
                      AppTheme.getGold(context),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${style.price} FCFA',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
                // Error message
                if (status == _UploadStatus.error && _errorMessages[index].isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _errorMessages[index],
                      style: const TextStyle(fontSize: 10, color: AppTheme.accentRed),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Status indicator
          _buildStatusIndicator(context, status),
        ],
      ),
    );
  }

  Widget _buildTag(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _buildStatusIndicator(BuildContext context, _UploadStatus status) {
    switch (status) {
      case _UploadStatus.pending:
        return Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppTheme.getBgGlass(context),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.hourglass_empty, size: 14, color: AppTheme.getTextTertiary(context)),
        );
      case _UploadStatus.uploading:
        return SizedBox(
          width: 28,
          height: 28,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.getGold(context)),
            ),
          ),
        );
      case _UploadStatus.done:
        return Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppTheme.accentGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.check, size: 16, color: AppTheme.accentGreen),
        );
      case _UploadStatus.error:
        return Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppTheme.accentRed.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.close, size: 16, color: AppTheme.accentRed),
        );
    }
  }
}
