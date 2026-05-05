import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../l10n/app_locale.dart';
import '../../services/api_client.dart';
import '../../services/admin_service.dart';
import '../../services/customer_service.dart';

class AdminTryOnScreen extends StatefulWidget {
  const AdminTryOnScreen({super.key});

  @override
  State<AdminTryOnScreen> createState() => _AdminTryOnScreenState();
}

class _AdminTryOnScreenState extends State<AdminTryOnScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  List<Map<String, dynamic>> _history = [];
  int _currentPage = 1;
  bool _hasMore = true;

  // Loaded styles for the style selector
  List<Map<String, dynamic>> _availableStyles = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
    _fetchStyles();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _fetchHistory({String? clientName}) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _currentPage = 1;
    });
    try {
      final query = <String, String>{'page': '1'};
      if (clientName != null && clientName.isNotEmpty) {
        query['clientName'] = clientName;
      }
      final res = await AdminService.instance.getAdminTryOnHistory(query: query);
      final data = res['data'] ?? res;
      final items = data['items'] ?? data['tryOns'] ?? data['history'] ?? [];
      final total = data['total'] ?? data['totalPages'] ?? 1;

      if (!mounted) return;
      setState(() {
        _history = List<Map<String, dynamic>>.from(items is List ? items : []);
        _hasMore = _currentPage < (total is int ? total : 1);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _currentPage + 1;
      final query = <String, String>{'page': '$nextPage'};
      final searchText = _searchController.text.trim();
      if (searchText.isNotEmpty) {
        query['clientName'] = searchText;
      }
      final res = await AdminService.instance.getAdminTryOnHistory(query: query);
      final data = res['data'] ?? res;
      final items = data['items'] ?? data['tryOns'] ?? data['history'] ?? [];
      final total = data['total'] ?? data['totalPages'] ?? 1;

      if (!mounted) return;
      setState(() {
        _history.addAll(List<Map<String, dynamic>>.from(items is List ? items : []));
        _currentPage = nextPage;
        _hasMore = nextPage < (total is int ? total : 1);
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _fetchStyles() async {
    try {
      final allItems = <Map<String, dynamic>>[];
      int page = 1;
      bool hasMore = true;

      while (hasMore) {
        final res = await CustomerService.instance.getStyles(query: {
          'page': page.toString(),
          'limit': '50',
        });
        final raw = res['items'] ?? res['styles'] ?? res['data'] ?? res;
        final data = raw is List ? raw : (raw is Map ? (raw['items'] ?? raw['styles'] ?? []) : []);

        if (data is List && data.isNotEmpty) {
          allItems.addAll(List<Map<String, dynamic>>.from(data));
          final total = res['total'] ?? res['totalPages'];
          final currentPage = res['page'] ?? page;
          if (total is int && currentPage is int) {
            hasMore = currentPage < total;
          } else {
            hasMore = data.length >= 50;
          }
          page++;
        } else {
          hasMore = false;
        }
      }

      if (!mounted) return;
      setState(() {
        _availableStyles = allItems;
      });
    } catch (e) {
      debugPrint('Failed to load styles for selector: $e');
    }
  }

  void _onSearch() {
    final text = _searchController.text.trim();
    _fetchHistory(clientName: text.isNotEmpty ? text : null);
  }

  void _showNewTryOnSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NewTryOnSheet(
        availableStyles: _availableStyles,
        onGenerated: () {
          _fetchHistory();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBgPrimary(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildSearchBar(),
            _buildNewTryOnCard(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Text(
                tr('tryOnHistory'),
                style: AppTheme.displayFont.copyWith(
                  fontSize: 18,
                  color: AppTheme.getTextPrimary(context),
                ),
              ),
            ),
            Expanded(child: _buildHistoryList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.getBgGlass(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.getBorder(context)),
              ),
              child: Icon(Icons.arrow_back_ios_new, size: 16, color: AppTheme.getTextSecondary(context)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('virtualTryOn'),
                  style: AppTheme.displayFont.copyWith(
                    fontSize: 24,
                    color: AppTheme.getTextPrimary(context),
                  ),
                ),
                Text(
                  tr('generateTryOnForClient'),
                  style: TextStyle(fontSize: 12, color: AppTheme.getTextSecondary(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.getBgGlass(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.getBorder(context)),
        ),
        child: TextField(
          controller: _searchController,
          onSubmitted: (_) => _onSearch(),
          style: TextStyle(fontSize: 14, color: AppTheme.getTextPrimary(context)),
          decoration: InputDecoration(
            hintText: tr('searchByClient'),
            hintStyle: TextStyle(color: AppTheme.getTextTertiary(context), fontSize: 13),
            prefixIcon: Icon(Icons.search, size: 20, color: AppTheme.getTextTertiary(context)),
            suffixIcon: GestureDetector(
              onTap: _onSearch,
              child: Icon(Icons.arrow_forward, size: 20, color: AppTheme.getGold(context)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  Widget _buildNewTryOnCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: GestureDetector(
        onTap: _showNewTryOnSheet,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.getBgGlass(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.getBorder(context)),
          ),
          child: Row(
            children: [
              Icon(Icons.add_a_photo_outlined, size: 20, color: AppTheme.getGold(context)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(tr('newTryOn'),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.getTextPrimary(context))),
              ),
              Text(tr('generateTryOnForClient'),
                style: TextStyle(fontSize: 11, color: AppTheme.getTextSecondary(context))),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: AppTheme.getTextTertiary(context), size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: AppTheme.accentRed),
            const SizedBox(height: 12),
            Text(
              tr('tryOnGenerateFailed'),
              style: TextStyle(fontSize: 14, color: AppTheme.getTextSecondary(context)),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _fetchHistory(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.getBgGlass(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.getBorder(context)),
                ),
                child: Text(
                  tr('retry'),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.getGold(context)),
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility_off_outlined, size: 48, color: AppTheme.getTextTertiary(context)),
            const SizedBox(height: 12),
            Text(
              tr('noTryOnHistory'),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.getTextSecondary(context)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: _history.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _history.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final item = _history[index];
        return _buildHistoryItem(item);
      },
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> item) {
    final clientName = item['clientName'] ?? item['client_name'] ?? '';
    final styleName = item['styleName'] ?? item['style_name'] ?? item['style']?['name'] ?? '';
    final date = item['createdAt'] ?? item['created_at'] ?? item['date'] ?? '';
    final resultImage = item['resultImage'] ?? item['result_image'] ?? item['resultUrl'] ?? '';
    final imageUrl = ApiClient.getImageUrl(resultImage?.toString());

    String formattedDate = '';
    if (date is String && date.isNotEmpty) {
      try {
        final dt = DateTime.parse(date);
        formattedDate = '${dt.day}/${dt.month}/${dt.year}';
      } catch (_) {
        formattedDate = date;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.getBgGlass(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.getBorder(context)),
      ),
      child: Row(
        children: [
          // Thumbnail
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.getGoldDim(context),
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Icon(Icons.image_not_supported_outlined, size: 22, color: AppTheme.getTextTertiary(context)),
                    ),
                  )
                : Center(
                    child: Icon(Icons.visibility_outlined, size: 22, color: AppTheme.getGold(context)),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clientName.toString(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.getTextPrimary(context),
                  ),
                ),
                if (styleName.toString().isNotEmpty)
                  Text(
                    styleName.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.getTextSecondary(context),
                    ),
                  ),
              ],
            ),
          ),
          if (formattedDate.isNotEmpty)
            Text(
              formattedDate,
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.getTextTertiary(context),
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════
//  New Try-On Bottom Sheet
// ══════════════════════════════════════

class _NewTryOnSheet extends StatefulWidget {
  final List<Map<String, dynamic>> availableStyles;
  final VoidCallback onGenerated;

  const _NewTryOnSheet({
    required this.availableStyles,
    required this.onGenerated,
  });

  @override
  State<_NewTryOnSheet> createState() => _NewTryOnSheetState();
}

class _NewTryOnSheetState extends State<_NewTryOnSheet> {
  final _clientNameController = TextEditingController();
  final _notesController = TextEditingController();
  final _picker = ImagePicker();

  XFile? _photoFile;
  Uint8List? _photoBytes;
  String? _selectedStyleId;
  String? _selectedStyleName;
  String _selectedHairColor = '';
  bool _isGenerating = false;

  static const _hairColors = [
    ('', 'colorNone'),
    ('black', 'colorBlack'),
    ('brown', 'colorBrown'),
    ('blonde', 'colorBlonde'),
    ('red', 'colorRed'),
    ('grey', 'colorGrey'),
    ('auburn', 'colorAuburn'),
    ('platinum', 'colorPlatinum'),
  ];

  @override
  void dispose() {
    _clientNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _photoFile = picked;
          _photoBytes = bytes;
        });
      }
    } catch (e) {
      debugPrint('Image pick error: $e');
    }
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.getBgSecondary(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_library_outlined, color: AppTheme.getGold(ctx)),
                title: Text(tr('gallery'), style: TextStyle(color: AppTheme.getTextPrimary(ctx))),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhoto(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt_outlined, color: AppTheme.getGold(ctx)),
                title: Text(tr('camera'), style: TextStyle(color: AppTheme.getTextPrimary(ctx))),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhoto(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStyleSelector() {
    final styles = widget.availableStyles;
    String genderFilter = 'women';
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.getBgSecondary(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx, scrollController) {
            return StatefulBuilder(
              builder: (ctx, setSheetState) {
                String normalizeGender(dynamic g) {
                  final raw = (g ?? 'women').toString().toLowerCase().trim();
                  if (raw == 'female' || raw == 'f' || raw == 'w') return 'women';
                  if (raw == 'male' || raw == 'm') return 'men';
                  return raw;
                }
                final filtered = genderFilter == 'all'
                    ? styles
                    : styles
                        .where((s) => normalizeGender(s['gender']) == genderFilter)
                        .toList();

                Widget genderTab(String value, IconData? icon, String label) {
                  final isActive = genderFilter == value;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setSheetState(() => genderFilter = value),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isActive ? AppTheme.getGoldDim(ctx) : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          border: isActive
                              ? Border.all(color: AppTheme.getGold(ctx).withValues(alpha: 0.3))
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (icon != null) ...[
                              Icon(
                                icon,
                                size: 18,
                                color: isActive
                                    ? AppTheme.getGold(ctx)
                                    : AppTheme.getTextTertiary(ctx),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                color: isActive
                                    ? AppTheme.getGold(ctx)
                                    : AppTheme.getTextTertiary(ctx),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 8),
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.getTextTertiary(ctx),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Text(
                        tr('selectStyle'),
                        style: AppTheme.displayFont.copyWith(
                          fontSize: 18,
                          color: AppTheme.getTextPrimary(ctx),
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.getBgSecondary(ctx),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.getBorder(ctx)),
                      ),
                      child: Row(
                        children: [
                          genderTab('all', null, tr('all')),
                          genderTab('women', Icons.female_rounded, tr('women')),
                          genderTab('men', Icons.male_rounded, tr('men')),
                        ],
                      ),
                    ),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                tr('noStylesYet'),
                                style: TextStyle(color: AppTheme.getTextSecondary(ctx)),
                              ),
                            )
                          : GridView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.78,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (ctx, i) {
                                final style = filtered[i];
                                final id = '${style['id'] ?? style['_id'] ?? ''}';
                                final name = style['name'] ?? '';
                                final imageUrl = ApiClient.getImageUrl(
                                  style['imageUrl']?.toString() ?? style['image']?.toString(),
                                );
                                final isSelected = _selectedStyleId == id;

                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedStyleId = id;
                                      _selectedStyleName = name.toString();
                                    });
                                    Navigator.pop(ctx);
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppTheme.getBgGlass(ctx),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppTheme.getGold(ctx)
                                            : AppTheme.getBorder(ctx),
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              imageUrl.isNotEmpty
                                                  ? Image.network(
                                                      imageUrl,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (_, _, _) => Container(
                                                        color: AppTheme.getBgSecondary(ctx),
                                                        child: Icon(Icons.style,
                                                            size: 28,
                                                            color: AppTheme.getTextTertiary(ctx)),
                                                      ),
                                                    )
                                                  : Container(
                                                      color: AppTheme.getBgSecondary(ctx),
                                                      child: Icon(Icons.style,
                                                          size: 28,
                                                          color: AppTheme.getTextTertiary(ctx)),
                                                    ),
                                              if (isSelected)
                                                Positioned(
                                                  top: 6,
                                                  right: 6,
                                                  child: Container(
                                                    padding: const EdgeInsets.all(4),
                                                    decoration: BoxDecoration(
                                                      color: AppTheme.getGold(ctx),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(Icons.check,
                                                        size: 14, color: Colors.white),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 8),
                                          child: Text(
                                            name.toString(),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: AppTheme.getTextPrimary(ctx),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _handleGenerate() async {
    // Validation
    if (_photoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('imageRequired')), backgroundColor: AppTheme.accentRed),
      );
      return;
    }
    if (_clientNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('clientName')), backgroundColor: AppTheme.accentRed),
      );
      return;
    }
    if (_selectedStyleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('selectStyle')), backgroundColor: AppTheme.accentRed),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final fields = <String, String>{
        'styleId': _selectedStyleId!,
        'clientName': _clientNameController.text.trim(),
      };
      if (_selectedHairColor.isNotEmpty) {
        fields['hairColor'] = _selectedHairColor;
      }
      if (_notesController.text.trim().isNotEmpty) {
        fields['notes'] = _notesController.text.trim();
      }

      await AdminService.instance.adminGenerateTryOn(
        photo: _photoFile!,
        fields: fields,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('tryOnGenerated')),
          backgroundColor: AppTheme.accentGreen,
        ),
      );
      widget.onGenerated();
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Failed to generate try-on: $e');
      if (!mounted) return;
      setState(() => _isGenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('tryOnGenerateFailed')),
          backgroundColor: AppTheme.accentRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.getBgPrimary(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag Handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.getTextTertiary(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      tr('newTryOn'),
                      style: AppTheme.displayFont.copyWith(
                        fontSize: 22,
                        color: AppTheme.getTextPrimary(context),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.getBgGlass(context),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.getBorder(context)),
                        ),
                        child: Icon(Icons.close, size: 18, color: AppTheme.getTextSecondary(context)),
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(20, 0, 20, bottomInset + 20),
                  children: [
                    // Photo Picker
                    GestureDetector(
                      onTap: _showImageSourcePicker,
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppTheme.getBgGlass(context),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _photoFile != null
                                ? AppTheme.getGold(context).withValues(alpha: 0.4)
                                : AppTheme.getBorder(context),
                            width: _photoFile != null ? 2 : 1,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _photoFile != null
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.memory(_photoBytes!, fit: BoxFit.cover),
                                  Positioned(
                                    bottom: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.6),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.edit, size: 16, color: Colors.white),
                                    ),
                                  ),
                                ],
                              )
                            : Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: AppTheme.getGoldDim(context),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.camera_alt_outlined, size: 32, color: AppTheme.getGold(context)),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      tr('tapToAddImage'),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.getTextSecondary(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Client Name
                    _buildLabel(tr('clientName')),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _clientNameController,
                      hint: 'e.g. Amara',
                    ),

                    const SizedBox(height: 20),

                    // Style Selector
                    _buildLabel(tr('selectStyle')),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _showStyleSelector,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppTheme.getBgGlass(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.getBorder(context)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _selectedStyleName ?? tr('selectStyle'),
                                style: TextStyle(
                                  fontSize: 15,
                                  color: _selectedStyleName != null
                                      ? AppTheme.getTextPrimary(context)
                                      : AppTheme.getTextTertiary(context),
                                ),
                              ),
                            ),
                            Icon(Icons.expand_more, size: 20, color: AppTheme.getTextSecondary(context)),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Hair Color Selector (optional)
                    _buildLabel('${tr('hairColor')} (${tr('optional')})'),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _hairColors.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (ctx, i) {
                          final color = _hairColors[i];
                          final isSelected = _selectedHairColor == color.$1;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedHairColor = color.$1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.getGoldDim(ctx)
                                    : AppTheme.getBgGlass(ctx),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.getGold(ctx).withValues(alpha: 0.5)
                                      : AppTheme.getBorder(ctx),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  tr(color.$2),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: isSelected
                                        ? AppTheme.getGold(ctx)
                                        : AppTheme.getTextSecondary(ctx),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Notes (optional)
                    _buildLabel('${tr('notes')} (${tr('optional')})'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _notesController,
                      hint: '...',
                      maxLines: 3,
                    ),

                    const SizedBox(height: 32),

                    // Generate Button
                    GestureDetector(
                      onTap: _isGenerating ? null : _handleGenerate,
                      child: Container(
                        width: double.infinity,
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _isGenerating
                                ? [
                                    AppTheme.getTextTertiary(context),
                                    AppTheme.getTextTertiary(context),
                                  ]
                                : [AppTheme.getGold(context), AppTheme.teal],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: _isGenerating ? [] : AppTheme.goldShadow,
                        ),
                        child: Center(
                          child: _isGenerating
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppTheme.getBgPrimary(context),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      tr('generating'),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.getBgPrimary(context),
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  tr('generate'),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.getBgPrimary(context),
                                  ),
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.getTextSecondary(context),
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getBgGlass(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.getBorder(context)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: TextStyle(
          fontSize: 15,
          color: AppTheme.getTextPrimary(context),
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: AppTheme.getTextTertiary(context)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
