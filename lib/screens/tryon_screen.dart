import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../theme/app_theme.dart';
import '../l10n/app_locale.dart';
import '../services/api_client.dart';
import '../services/customer_service.dart';
import '../services/public_service.dart';
import '../services/storage_service.dart';
import '../services/tryon_cache_service.dart';
import '../widgets/app_toast.dart';
import 'guest/guest_info_sheet.dart';

class TryOnScreen extends StatefulWidget {
  /// When true, the screen uses the unauthenticated /public/salons endpoints
  /// and routes WebSocket progress through a guest sessionId room.
  final bool guestMode;
  const TryOnScreen({super.key, this.guestMode = false});

  @override
  State<TryOnScreen> createState() => _TryOnScreenState();
}

class _TryOnScreenState extends State<TryOnScreen>
    with TickerProviderStateMixin {
  // Photo state
  Uint8List? _userPhoto;
  XFile? _userPhotoFile;
  bool _hasPhoto = false;

  // Gender, category & subcategory
  String _selectedGender = 'women';
  String _selectedCategory = 'all';
  String? _selectedSubcategory;
  List<String> _subcategories = [];
  bool _loadingSubcategories = false;

  // Salon custom category id → name. The catalogue (guest) response carries
  // only `categoryId`, so we resolve the display name from this map.
  Map<String, String> _categoryNames = {};

  // Styles from backend API
  List<Map<String, dynamic>> _allStyles = [];
  bool _loadingStyles = true;
  String? _stylesError;

  // Style selection
  Map<String, dynamic>? _selectedStyle;

  // AI generation
  bool _isGenerating = false;
  Uint8List? _generatedImage;
  String? _errorMessage;
  String? _debugInfo;
  String _generationStatus = '';
  int _generationProgress = 0;

  // Socket.IO for real-time progress
  IO.Socket? _socket;

  // Color
  int _selectedColorIndex = 0;
  final _hairColorNames = [
    'natural black',
    'dark brown',
    'medium brown',
    'golden blonde',
    'deep red',
    'dark blue',
    'platinum blonde',
  ];
  final _hairColors = [
    const Color(0xFF1A1A1A),
    const Color(0xFF3D2314),
    const Color(0xFF8B4513),
    const Color(0xFFDAA520),
    const Color(0xFFC41E3A),
    const Color(0xFF2E2E5E),
    const Color(0xFFE8D5B7),
  ];

  // Animation
  late AnimationController _pulseController;
  late AnimationController _generatingController;
  late AnimationController _scissorsController;
  late AnimationController _sparkleController;
  late TabController _genderTabController;
  final _imagePicker = ImagePicker();

  // Simulated progress fallback when socket events don't arrive
  bool _socketProgressReceived = false;

  bool get _guest => widget.guestMode;
  String? _guestSessionId;

  Future<String> _ensureGuestSessionId() async {
    if (_guestSessionId != null) return _guestSessionId!;
    final existing = StorageService.instance.guestSessionId;
    if (existing != null && existing.isNotEmpty) {
      _guestSessionId = existing;
      return existing;
    }
    final rng = math.Random();
    final id = 'g-${DateTime.now().millisecondsSinceEpoch}-${rng.nextInt(1 << 32).toRadixString(16)}';
    await StorageService.instance.saveGuestSessionId(id);
    _guestSessionId = id;
    return id;
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    _generatingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _scissorsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _genderTabController = TabController(length: 2, vsync: this);
    _genderTabController.addListener(() {
      if (!_genderTabController.indexIsChanging) {
        setState(() {
          _selectedGender = _genderTabController.index == 0 ? 'women' : 'men';
          _selectedCategory = 'all';
          _selectedSubcategory = null;
          _selectedStyle = null;
        });
      }
    });
    _fetchStyles();
    _loadCategoryNames();
    _connectSocket();
  }

  void _connectSocket() async {
    final roomKey = _guest
        ? await _ensureGuestSessionId()
        : (StorageService.instance.userId ?? '');
    final queryField = _guest ? 'sessionId' : 'customerId';
    _socket = IO.io(
      '${ApiClient.serverUrl}/try-on',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setQuery({queryField: roomKey})
          .disableAutoConnect()
          .enableReconnection()
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('[TryOn] Socket connected (id=${_socket?.id}, url=${ApiClient.serverUrl}/try-on, $queryField=$roomKey)');
    });
    _socket!.onDisconnect((reason) {
      debugPrint('[TryOn] Socket disconnected (reason=$reason)');
    });
    _socket!.onConnectError((err) {
      debugPrint('[TryOn] Socket connect error: $err');
    });
    _socket!.onError((err) {
      debugPrint('[TryOn] Socket error: $err');
    });

    _socket!.on('tryon:progress', (data) {
      debugPrint('[TryOn] Progress event: $data');
      if (!mounted || !_isGenerating) return;
      _socketProgressReceived = true;
      setState(() {
        _generationProgress = (data['progress'] as num?)?.toInt() ?? _generationProgress;
        _generationStatus = data['step']?.toString() ?? _generationStatus;
      });
    });

    _socket!.on('tryon:complete', (data) {
      debugPrint('[TryOn] Complete event: $data');
      if (!mounted) return;
      setState(() {
        _generationProgress = 100;
        _generationStatus = tr('done');
      });
      // The HTTP response handler will take care of displaying the image
    });

    _socket!.on('tryon:error', (data) {
      debugPrint('[TryOn] Error event: $data');
      if (!mounted) return;
      setState(() {
        _isGenerating = false;
        _generationProgress = 0;
        _errorMessage = data['error']?.toString() ?? tr('tryOnFailed');
      });
      _generatingController.stop();
      _scissorsController.stop();
      _sparkleController.stop();
    });

    debugPrint('[TryOn] Connecting socket to ${ApiClient.serverUrl}/try-on with $queryField=$roomKey...');
    _socket!.connect();
  }

  void _disconnectSocket() {
    _socket?.dispose();
    _socket = null;
  }

  /// Load the salon's custom category id→name map so guest-mode styles (which
  /// only carry `categoryId`) can show their category name in the chips.
  Future<void> _loadCategoryNames() async {
    final salonId = StorageService.instance.selectedSalonId;
    if (salonId == null || salonId.isEmpty) return;
    try {
      final res = await PublicService.instance.getSalonCategories(salonId);
      final raw = res['data'] ?? res['items'] ?? res['categories'] ?? res;
      final list = raw is List
          ? raw
          : (raw is Map ? (raw['items'] ?? raw['categories'] ?? []) : []);
      final map = <String, String>{};
      for (final c in list.whereType<Map>()) {
        final id = c['id']?.toString();
        final name = c['name']?.toString();
        if (id != null && id.isNotEmpty && name != null && name.isNotEmpty) {
          map[id] = name;
        }
      }
      if (mounted && map.isNotEmpty) setState(() => _categoryNames = map);
    } catch (e) {
      debugPrint('[TryOn] Failed to load category names: $e');
    }
  }

  Future<void> _fetchStyles() async {
    try {
      final allItems = <Map<String, dynamic>>[];

      if (_guest) {
        // Guest mode: styles come from the salon catalogue (no auth, no paging).
        final salonId = StorageService.instance.selectedSalonId;
        if (salonId != null) {
          final res = await PublicService.instance.getCatalogue(salonId);
          final data = (res['data'] ?? res) as Map<String, dynamic>;
          final raw = data['styles'] ?? data['hairstyles'] ?? [];
          if (raw is List) {
            allItems.addAll(List<Map<String, dynamic>>.from(raw.whereType<Map>()));
          }
        }
      } else {
        // Fetch all styles with a high limit to get everything (48+ styles)
        int page = 1;
        bool hasMore = true;

        while (hasMore) {
          final response = await CustomerService.instance.getStyles(query: {
            'page': page.toString(),
            'limit': '50',
          });
          final raw = response['items'] ?? response['styles'] ?? response['data'] ?? response;
          final data = raw is List ? raw : (raw is Map ? (raw['items'] ?? raw['styles'] ?? []) : []);

          if (data is List && data.isNotEmpty) {
            allItems.addAll(List<Map<String, dynamic>>.from(data));
            // Check if there are more pages
            final total = response['total'] ?? response['totalPages'];
            final currentPage = response['page'] ?? page;
            if (total is int && currentPage is int) {
              hasMore = currentPage < total;
            } else {
              // If no pagination info, check if we got a full page
              hasMore = data.length >= 50;
            }
            page++;
          } else {
            hasMore = false;
          }
        }
      }

      if (allItems.isNotEmpty && mounted) {
        setState(() {
          _allStyles = allItems;
          _stylesError = null;
          _loadingStyles = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _stylesError = tr('failedToLoadStyles');
            _loadingStyles = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _stylesError = tr('failedToLoadStyles');
          _loadingStyles = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _disconnectSocket();
    _pulseController.dispose();
    _generatingController.dispose();
    _scissorsController.dispose();
    _sparkleController.dispose();
    _genderTabController.dispose();
    super.dispose();
  }

  Future<void> _fetchSubcategories(String category) async {
    if (category == 'all') {
      setState(() { _subcategories = []; _selectedSubcategory = null; });
      return;
    }
    setState(() { _loadingSubcategories = true; _subcategories = []; _selectedSubcategory = null; });
    try {
      final res = await CustomerService.instance.getStyleSubcategories(query: {'category': category});
      final data = res['subcategories'] ?? res['data'] ?? res;
      if (data is List && mounted) {
        setState(() {
          _subcategories = List<String>.from(data.map((e) => e is Map ? (e['name']?.toString() ?? '') : e.toString()));
          _loadingSubcategories = false;
        });
      } else {
        if (mounted) setState(() => _loadingSubcategories = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSubcategories = false);
    }
  }

  /// A style's effective category: the salon's custom category name when set,
  /// otherwise the legacy `category` enum. This is what drives the try-on
  /// chips, so newly created custom categories show up here automatically.
  String _effectiveCategory(Map<String, dynamic> s) {
    // 1. Logged-in /styles embeds the full custom category object.
    final custom = s['customCategory'];
    final name = custom is Map ? custom['name']?.toString().trim() : null;
    if (name != null && name.isNotEmpty) return name;
    // 2. Guest catalogue carries only categoryId — resolve via the salon map.
    final catId = s['categoryId']?.toString();
    if (catId != null && catId.isNotEmpty) {
      final mapped = _categoryNames[catId]?.trim();
      if (mapped != null && mapped.isNotEmpty) return mapped;
    }
    // 3. Fall back to the legacy category enum.
    return (s['category'] ?? '').toString();
  }

  List<Map<String, dynamic>> get _filteredStyles {
    return _allStyles.where((s) {
      final gender = (s['gender'] ?? '').toString().toLowerCase();
      if (gender != _selectedGender) return false;
      if (_selectedCategory != 'all') {
        final category = _effectiveCategory(s).toLowerCase();
        if (category != _selectedCategory) return false;
      }
      if (_selectedSubcategory != null) {
        final sub = (s['subcategory'] ?? '').toString().toLowerCase();
        if (sub != _selectedSubcategory!.toLowerCase()) return false;
      }
      return true;
    }).toList();
  }

  List<String> get _availableCategories {
    final genderStyles =
        _allStyles.where((s) {
          final g = (s['gender'] ?? '').toString().toLowerCase();
          return g == _selectedGender;
        });
    final cats = <String>{'all'};
    for (final s in genderStyles) {
      final cat = _effectiveCategory(s).toLowerCase();
      if (cat.isNotEmpty) cats.add(cat);
    }
    return cats.toList();
  }

  static const _categoryLabelKeys = <String, String>{
    'all': 'catAll',
    'wigs': 'catWigs',
    'braids': 'catBraids',
    'locs': 'catLocs',
    'curls': 'catCurls',
    'fades': 'catFades',
    'twists': 'catTwists',
    'weaves': 'catWeaves',
    'natural': 'catNatural',
    'cornrows': 'catCornrows',
    'updos': 'catUpdos',
    'color': 'catColor',
  };

  String _categoryLabel(String cat) {
    final key = _categoryLabelKeys[cat];
    if (key != null) return tr(key);
    if (cat.isEmpty) return cat;
    // Custom category: title-case each word for display.
    return cat
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  static const _categoryIcons = <String, IconData>{
    'all': Icons.grid_view_rounded,
    'wigs': Icons.face_retouching_natural,
    'braids': Icons.texture_rounded,
    'locs': Icons.waves_rounded,
    'curls': Icons.bubble_chart_rounded,
    'fades': Icons.content_cut_rounded,
    'twists': Icons.cyclone_rounded,
    'weaves': Icons.layers_rounded,
    'natural': Icons.eco_rounded,
    'cornrows': Icons.view_day_rounded,
    'updos': Icons.vertical_align_top_rounded,
    'color': Icons.palette_rounded,
  };

  IconData _categoryIcon(String cat) {
    return _categoryIcons[cat] ?? Icons.style_rounded;
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _userPhoto = bytes;
          _userPhotoFile = picked;
          _hasPhoto = true;
          _generatedImage = null;
          _errorMessage = null;
        });
      }
    } catch (e) {
      _showToast(tr('couldNotAccess'), type: ToastType.error, subtitle: '$e');
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.getBgSecondary(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.getTextTertiary(ctx),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(tr('uploadPhoto'),
                  style: AppTheme.displayFont.copyWith(
                    fontSize: 20,
                    color: AppTheme.getTextPrimary(ctx),
                  )),
              const SizedBox(height: 6),
              Text(
                tr('takeSelfie'),
                style: TextStyle(
                    fontSize: 13, color: AppTheme.getTextSecondary(ctx)),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: _SourceOption(
                      icon: Icons.camera_alt_rounded,
                      label: tr('camera'),
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.camera);
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _SourceOption(
                      icon: Icons.photo_library_rounded,
                      label: tr('gallery'),
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.gallery);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generateTryOn({bool skipCache = false}) async {
    if (_userPhoto == null || _selectedStyle == null || _userPhotoFile == null) return;

    // Guest mode requires name/phone/email to persist the try-on row.
    if (_guest && !StorageService.instance.hasGuestProfile) {
      final saved = await GuestInfoSheet.show(context,
          title: 'Before we try a style',
          subtitle: 'The salon needs these details so they can reach out about your look.');
      if (saved != true) return;
    }

    final style = _selectedStyle!;
    final styleId = style['id']?.toString() ?? style['name']?.toString() ?? '';

    // Check cache first - instant load if already generated (unless skipping)
    if (!skipCache) {
      final cached = await TryOnCacheService.instance.getCached(
        userPhoto: _userPhoto!,
        styleId: styleId,
        colorIndex: _selectedColorIndex,
      );
      if (cached != null && mounted) {
        setState(() {
          _generatedImage = cached;
          _swiperPosition = 0.5;
        });
        _showToast(tr('loadedFromCache'));
        return;
      }
    }

    setState(() {
      _isGenerating = true;
      _generatedImage = null;
      _errorMessage = null;
      _generationProgress = 0;
      _generationStatus = tr('analyzingPhoto');
    });
    _socketProgressReceived = false;
    _generatingController.repeat();
    _scissorsController.repeat();
    _sparkleController.repeat();

    // Simulated progress that runs until real socket events arrive or HTTP completes
    _runSimulatedProgress();

    try {
      Map<String, dynamic> result;
      if (_guest) {
        final salonId = StorageService.instance.selectedSalonId;
        if (salonId == null) {
          throw Exception('No salon selected');
        }
        final sessionId = await _ensureGuestSessionId();
        final s = StorageService.instance;
        result = await PublicService.instance.generateGuestTryOn(
          salonId,
          photo: _userPhotoFile!,
          sessionId: sessionId,
          fields: {
            'clientName': s.guestName ?? '',
            'clientPhone': s.guestPhone ?? '',
            'clientEmail': s.guestEmail ?? '',
            'styleName': style['name']?.toString() ?? '',
            'styleDescription': style['description']?.toString() ?? '',
            if (_selectedColorIndex > 0) 'hairColor': _hairColorNames[_selectedColorIndex],
            if (style['id'] != null) 'styleId': style['id'].toString(),
          },
        );
      } else {
        result = await CustomerService.instance.generateTryOnWithPhoto(
          photo: _userPhotoFile!,
          fields: {
            'styleName': style['name']?.toString() ?? '',
            'styleDescription': style['description']?.toString() ?? '',
            if (_selectedColorIndex > 0) 'hairColor': _hairColorNames[_selectedColorIndex],
            if (style['id'] != null) 'styleId': style['id'].toString(),
          },
        );
      }
      if (!mounted) return;

      Uint8List? imageBytes;

      // Try to get the generated image from the response
      final data = result['data'] ?? result;
      final rawImageUrl = data['imageUrl'] ?? data['image'] ?? data['generatedImage'];
      if (rawImageUrl != null) {
        final fullUrl = ApiClient.getImageUrl(rawImageUrl.toString());
        final response = await http.get(Uri.parse(fullUrl));
        if (response.statusCode == 200) {
          imageBytes = response.bodyBytes;
        }
      } else if (data['imageBase64'] != null) {
        imageBytes = base64Decode(data['imageBase64']);
      }

      if (imageBytes != null && mounted) {
        // Save to cache for instant loading next time
        TryOnCacheService.instance.saveToCache(
          userPhoto: _userPhoto!,
          styleId: styleId,
          colorIndex: _selectedColorIndex,
          generatedImage: imageBytes,
        );
        setState(() {
          _generatedImage = imageBytes;
          _isGenerating = false;
          _generationStatus = '';
          _swiperPosition = 0.5;
        });
      } else if (mounted) {
        setState(() {
          _errorMessage = tr('tryOnFailed');
          _isGenerating = false;
          _generationStatus = '';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isGenerating = false;
        _generationStatus = '';
      });
    }
    _generatingController.stop();
    _scissorsController.stop();
    _sparkleController.stop();
  }

  void _runSimulatedProgress() async {
    final steps = [
      (15, tr('analyzingPhoto'), 1500),
      (30, tr('processingFeatures'), 2000),
      (45, tr('applyingStyle'), 2500),
      (60, tr('generatingImage'), 3000),
      (75, tr('refiningDetails'), 3000),
      (85, tr('almostDone'), 4000),
      (92, tr('finalTouches'), 5000),
    ];

    for (final (progress, status, delayMs) in steps) {
      await Future.delayed(Duration(milliseconds: delayMs));
      if (!mounted || !_isGenerating || _socketProgressReceived) return;
      setState(() {
        _generationProgress = progress;
        _generationStatus = status;
      });
    }
  }

  void _resetTryon() {
    setState(() {
      _userPhoto = null;
      _userPhotoFile = null;
      _hasPhoto = false;
      _generatedImage = null;
      _selectedStyle = null;
      _errorMessage = null;
      _isGenerating = false;
      _generationProgress = 0;
      _generationStatus = '';
    });
  }

  void _showToast(String message, {ToastType type = ToastType.success, String? subtitle}) {
    if (!mounted) return;
    AppToast.show(context, message: message, type: type, subtitle: subtitle);
  }

  // ───────── RESPONSIVE (tablet) ─────────
  bool get _isTablet => MediaQuery.of(context).size.width >= 600;

  @override
  Widget build(BuildContext context) {
    if (_isTablet) return _buildTabletLayout();
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _buildHeader(),
          const SizedBox(height: 16),
          _buildPhotoZone(),
          if (_errorMessage != null) _buildError(),
          if (_hasPhoto) _buildActionBar(),
          if (_hasPhoto && _generatedImage != null) _buildBookForStyleButton(),
          if (_hasPhoto && _generatedImage != null) _buildColorPalette(),
          const SizedBox(height: 20),
          _buildGenderTabs(),
          const SizedBox(height: 14),
          _buildCategoryChips(),
          if (_subcategories.isNotEmpty || _loadingSubcategories) ...[
            const SizedBox(height: 8),
            _buildSubcategoryChips(),
          ],
          const SizedBox(height: 6),
          _buildStyleCount(),
          const SizedBox(height: 10),
          _buildStyleGrid(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // Two-pane tablet layout that fills the screen: try-on workspace on the
  // left, scrollable style browser on the right. Each pane scrolls on its own.
  Widget _buildTabletLayout() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT — try-on workspace
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  _buildHeader(),
                  const SizedBox(height: 16),
                  _buildPhotoZone(),
                  if (_errorMessage != null) _buildError(),
                  if (_hasPhoto) _buildActionBar(),
                  if (_hasPhoto && _generatedImage != null)
                    _buildBookForStyleButton(),
                  if (_hasPhoto && _generatedImage != null) _buildColorPalette(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // RIGHT — style browser
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  _buildGenderTabs(),
                  const SizedBox(height: 14),
                  _buildCategoryChips(),
                  if (_subcategories.isNotEmpty || _loadingSubcategories) ...[
                    const SizedBox(height: 8),
                    _buildSubcategoryChips(),
                  ],
                  const SizedBox(height: 6),
                  _buildStyleCount(),
                  const SizedBox(height: 10),
                  _buildStyleGrid(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────── HEADER ─────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset('assets/logo.png', height: 44, fit: BoxFit.contain),
          const SizedBox(height: 4),
          Text(tr('tryOnSub'),
              style: TextStyle(
                  fontSize: 12, color: AppTheme.getTextSecondary(context))),
        ],
      ),
    );
  }

  // ───────── PHOTO ZONE ─────────
  Widget _buildPhotoZone() {
    final frame = AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        height: _isTablet ? null : 340,
        decoration: BoxDecoration(
          color: AppTheme.getBgSecondary(context),
          borderRadius: BorderRadius.circular(24),
          border: !_hasPhoto
              ? Border.all(
                  color: AppTheme.getGold(context).withValues(alpha: 0.2),
                  width: 2)
              : null,
          boxShadow: _hasPhoto
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (!_hasPhoto) _buildUploadPlaceholder(),
            if (_hasPhoto && _generatedImage == null && !_isGenerating)
              Image.memory(_userPhoto!, fit: BoxFit.cover),
            if (_isGenerating) _buildGeneratingState(),
            if (_generatedImage != null) _buildResultView(),
          ],
        ),
      );
    return GestureDetector(
      onTap: (!_hasPhoto || (!_isGenerating && _generatedImage == null))
          ? _showImageSourceDialog
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: _isTablet
            ? AspectRatio(aspectRatio: 3 / 4, child: frame)
            : frame,
      ),
    );
  }

  Widget _buildUploadPlaceholder() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.getGoldDim(context),
                  border: Border.all(
                      color:
                          AppTheme.getGold(context).withValues(alpha: 0.3),
                      width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.getGold(context)
                          .withValues(alpha: 0.08 * _pulseController.value),
                      blurRadius: 30 + 20 * _pulseController.value,
                      spreadRadius: 5 * _pulseController.value,
                    ),
                  ],
                ),
                child: Icon(Icons.add_a_photo_rounded,
                    color: AppTheme.getGold(context).withValues(alpha: 0.6),
                    size: 36),
              ),
              const SizedBox(height: 20),
              Text(tr('tapUpload'),
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.getTextPrimary(context))),
              const SizedBox(height: 4),
              Text(tr('tapUploadSub'),
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.getTextTertiary(context))),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGeneratingState() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Darkened user photo backdrop
        ColorFiltered(
          colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.65), BlendMode.darken),
          child: Image.memory(_userPhoto!, fit: BoxFit.cover),
        ),
        // Floating sparkles
        ...List.generate(8, (i) {
          final offsets = [
            const Offset(0.15, 0.2), const Offset(0.8, 0.15),
            const Offset(0.1, 0.7), const Offset(0.85, 0.65),
            const Offset(0.5, 0.1), const Offset(0.3, 0.85),
            const Offset(0.7, 0.8), const Offset(0.55, 0.35),
          ];
          return AnimatedBuilder(
            animation: _sparkleController,
            builder: (context, _) {
              final phase = (_sparkleController.value + i * 0.125) % 1.0;
              final opacity = (phase < 0.5 ? phase * 2 : (1.0 - phase) * 2).clamp(0.0, 1.0);
              final scale = 0.4 + opacity * 0.6;
              return Positioned(
                left: offsets[i].dx * MediaQuery.of(context).size.width * 0.8,
                top: offsets[i].dy * 400,
                child: Opacity(
                  opacity: opacity * 0.7,
                  child: Transform.scale(
                    scale: scale,
                    child: Icon(
                      i.isEven ? Icons.diamond_outlined : Icons.star_rounded,
                      color: AppTheme.teal,
                      size: i < 4 ? 14 : 10,
                    ),
                  ),
                ),
              );
            },
          );
        }),
        // Central animation cluster
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer rotating ring
                    AnimatedBuilder(
                      animation: _generatingController,
                      builder: (context, _) => Transform.rotate(
                        angle: _generatingController.value * 2 * 3.14159,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.teal.withValues(alpha: 0.15),
                              width: 1.5,
                            ),
                          ),
                          child: Stack(
                            children: [
                              // Orbiting dot 1
                              Positioned(
                                top: 0, left: 54,
                                child: Container(
                                  width: 8, height: 8,
                                  decoration: BoxDecoration(
                                    color: AppTheme.teal.withValues(alpha: 0.8),
                                    shape: BoxShape.circle,
                                    boxShadow: [BoxShadow(color: AppTheme.teal.withValues(alpha: 0.4), blurRadius: 6)],
                                  ),
                                ),
                              ),
                              // Orbiting dot 2
                              Positioned(
                                bottom: 0, left: 54,
                                child: Container(
                                  width: 6, height: 6,
                                  decoration: BoxDecoration(
                                    color: AppTheme.teal.withValues(alpha: 0.5),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Inner pulsing glow
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, _) => Container(
                        width: 80 + _pulseController.value * 10,
                        height: 80 + _pulseController.value * 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppTheme.teal.withValues(alpha: 0.12),
                              AppTheme.teal.withValues(alpha: 0.02),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Scissors icon — snip animation
                    AnimatedBuilder(
                      animation: _scissorsController,
                      builder: (context, _) {
                        final snip = (_scissorsController.value * 4 % 1.0);
                        final angle = snip < 0.5 ? snip * 0.3 : (1.0 - snip) * 0.3;
                        return Transform.rotate(
                          angle: -0.4 + angle,
                          child: Icon(
                            Icons.content_cut_rounded,
                            color: AppTheme.teal.withValues(alpha: 0.9),
                            size: 30,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Status text with shimmer
              AnimatedBuilder(
                animation: _generatingController,
                builder: (context, _) {
                  return ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        AppTheme.teal.withValues(alpha: 0.6),
                        AppTheme.gold,
                        AppTheme.teal.withValues(alpha: 0.6),
                      ],
                      stops: [
                        (_generatingController.value - 0.3).clamp(0.0, 1.0),
                        _generatingController.value,
                        (_generatingController.value + 0.3).clamp(0.0, 1.0),
                      ],
                    ).createShader(bounds),
                    child: Text(
                      _generationStatus,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              // Progress bar with percentage
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    // Percentage text
                    Text(
                      '${_generationProgress}%',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.teal,
                        shadows: [
                          Shadow(
                            color: AppTheme.teal.withValues(alpha: 0.5),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Animated progress bar
                    AnimatedBuilder(
                      animation: _generatingController,
                      builder: (context, _) {
                        return Container(
                          height: 6,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: Stack(
                              children: [
                                // Progress fill
                                FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: (_generationProgress / 100).clamp(0.0, 1.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(3),
                                      gradient: LinearGradient(
                                        colors: [
                                          AppTheme.teal,
                                          AppTheme.teal.withValues(alpha: 0.8),
                                          AppTheme.gold,
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.teal.withValues(alpha: 0.6),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Shimmer overlay on the filled portion
                                FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: (_generationProgress / 100).clamp(0.0, 1.0),
                                  child: ShaderMask(
                                    shaderCallback: (bounds) => LinearGradient(
                                      colors: [
                                        Colors.white.withValues(alpha: 0.0),
                                        Colors.white.withValues(alpha: 0.3),
                                        Colors.white.withValues(alpha: 0.0),
                                      ],
                                      stops: [
                                        (_generatingController.value - 0.3).clamp(0.0, 1.0),
                                        _generatingController.value,
                                        (_generatingController.value + 0.3).clamp(0.0, 1.0),
                                      ],
                                    ).createShader(bounds),
                                    blendMode: BlendMode.srcATop,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(3),
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr('aiMagic'),
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.4)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  double _swiperPosition = 0.5; // 0.0 = all after, 1.0 = all before

  void _showRegenerateDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getBgSecondary(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.refresh_rounded, color: AppTheme.getGold(context), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tr('regenerateTitle'),
                style: AppTheme.displayFont.copyWith(
                  fontSize: 18,
                  color: AppTheme.getTextPrimary(context),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          tr('regenerateMessage'),
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.getTextSecondary(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              tr('cancel'),
              style: TextStyle(color: AppTheme.getTextTertiary(context)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _generateTryOn(skipCache: true);
            },
            style: TextButton.styleFrom(
              backgroundColor: AppTheme.getGoldDim(context),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              tr('regenerate'),
              style: TextStyle(
                color: AppTheme.getGold(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final dividerX = width * _swiperPosition;

        return GestureDetector(
          onLongPress: _showRegenerateDialog,
          onHorizontalDragUpdate: (details) {
            setState(() {
              _swiperPosition =
                  (details.localPosition.dx / width).clamp(0.05, 0.95);
            });
          },
          onHorizontalDragStart: (details) {
            setState(() {
              _swiperPosition =
                  (details.localPosition.dx / width).clamp(0.05, 0.95);
            });
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // AFTER image (full width, underneath)
              Image.memory(_generatedImage!, fit: BoxFit.cover),

              // BEFORE image (clipped by swiper position)
              ClipRect(
                clipper: _LeftClipper(dividerX),
                child: Image.memory(_userPhoto!, fit: BoxFit.cover),
              ),

              // BEFORE label
              Positioned(
                bottom: 12,
                left: 10,
                child: AnimatedOpacity(
                  opacity: _swiperPosition > 0.15 ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(tr('before'),
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: Colors.white)),
                  ),
                ),
              ),

              // AFTER label
              Positioned(
                bottom: 12,
                right: 10,
                child: AnimatedOpacity(
                  opacity: _swiperPosition < 0.85 ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(tr('after'),
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: AppTheme.teal)),
                  ),
                ),
              ),

              // Divider line
              Positioned(
                left: dividerX - 1,
                top: 0,
                bottom: 0,
                child: Container(width: 2, color: AppTheme.teal),
              ),

              // Draggable handle
              Positioned(
                left: dividerX - 18,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.teal,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 2)),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chevron_left,
                            color: AppTheme.bgPrimary, size: 14),
                        Icon(Icons.chevron_right,
                            color: AppTheme.bgPrimary, size: 14),
                      ],
                    ),
                  ),
                ),
              ),

              // AI Generated badge
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.teal.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.diamond_outlined,
                          size: 12, color: AppTheme.bgPrimary),
                      const SizedBox(width: 4),
                      Text(tr('aiGenerated'),
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.bgPrimary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ───────── ERROR ─────────
  Widget _buildError() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.accentRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppTheme.accentRed.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline,
                  color: AppTheme.accentRed, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.accentRed),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() {
                  _errorMessage = null;
                  _debugInfo = null;
                }),
                child: const Icon(Icons.close,
                    color: AppTheme.accentRed, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              GestureDetector(
                onTap: _runDiagnostics,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.accentRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bug_report,
                          color: AppTheme.accentRed, size: 14),
                      SizedBox(width: 4),
                      Text('Diagnose',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.accentRed)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_selectedStyle != null)
                GestureDetector(
                  onTap: _generateTryOn,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.teal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh, color: AppTheme.teal, size: 14),
                        const SizedBox(width: 4),
                        Text(tr('retry'),
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.teal)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (_debugInfo != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Debug: $_debugInfo',
                style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textTertiary,
                    fontFamily: 'monospace'),
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _errorMessage = 'Running diagnostics...';
      _debugInfo = null;
    });

    try {
      // Check backend connectivity by fetching styles
      await CustomerService.instance.getStyles();
      setState(() {
        _errorMessage = 'Backend connection OK. Try generating again.';
        _debugInfo = 'Backend API is reachable.';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Cannot reach backend server. Please check your connection.';
        _debugInfo = e.toString();
      });
    }
  }

  // ───────── ACTION BAR ─────────
  Widget _buildActionBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ActionButton(
            icon: Icons.camera_alt_outlined,
            label: tr('newPhoto'),
            onTap: _showImageSourceDialog,
          ),
          if (_generatedImage != null) ...[
            const SizedBox(width: 10),
            _ActionButton(
              icon: Icons.bookmark_outline,
              label: tr('save'),
              onTap: () => _showToast(tr('styleSaved')),
            ),
            const SizedBox(width: 10),
            _ActionButton(
              icon: Icons.share_outlined,
              label: tr('share'),
              onTap: () => _showToast(tr('shareCopied')),
            ),
          ],
          const SizedBox(width: 10),
          _ActionButton(
            icon: Icons.refresh,
            label: tr('reset'),
            onTap: _resetTryon,
          ),
        ],
      ),
    );
  }

  // ───────── BOOK FOR THIS STYLE ─────────
  Widget _buildBookForStyleButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            AppToast.show(
              context,
              message: tr('bookForStyle'),
              subtitle: _selectedStyle != null ? (_selectedStyle!['name']?.toString() ?? '') : null,
              type: ToastType.booking,
            );
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.getGold(context),
                  AppTheme.getGold(context).withValues(alpha: 0.85),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.getGold(context).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 18, color: AppTheme.getBgPrimary(context)),
                const SizedBox(width: 10),
                Text(
                  tr('bookForStyle'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.getBgPrimary(context),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───────── COLOR PALETTE ─────────
  Widget _buildColorPalette() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(tr('color'),
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textTertiary)),
          const SizedBox(width: 10),
          ...List.generate(_hairColors.length, (i) {
            return GestureDetector(
              onTap: () {
                setState(() => _selectedColorIndex = i);
                if (_selectedStyle != null && _userPhoto != null) {
                  _generateTryOn();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 26,
                height: 26,
                margin: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: _hairColors[i],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _selectedColorIndex == i
                        ? AppTheme.gold
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ───────── GENDER TABS ─────────
  Widget _buildGenderTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.getBgSecondary(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.getBorder(context)),
      ),
      child: TabBar(
        controller: _genderTabController,
        indicator: BoxDecoration(
          color: AppTheme.getGoldDim(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppTheme.getGold(context).withValues(alpha: 0.3)),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: AppTheme.getGold(context),
        unselectedLabelColor: AppTheme.getTextTertiary(context),
        labelStyle:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.all(4),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.female_rounded, size: 18),
                const SizedBox(width: 6),
                Text(tr('women')),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.male_rounded, size: 18),
                const SizedBox(width: 6),
                Text(tr('men')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────── CATEGORY CHIPS ─────────
  Widget _buildCategoryChips() {
    if (_loadingStyles || _stylesError != null) return const SizedBox.shrink();
    final categories = _availableCategories;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = cat == _selectedCategory;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategory = cat;
                _selectedSubcategory = null;
              });
              _fetchSubcategories(cat);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.getGoldDim(context)
                    : AppTheme.getBgGlass(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.getGold(context).withValues(alpha: 0.4)
                      : AppTheme.getBorder(context),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _categoryIcon(cat),
                    size: 16,
                    color: isSelected
                        ? AppTheme.getGold(context)
                        : AppTheme.getTextTertiary(context),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _categoryLabel(cat),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? AppTheme.getGold(context)
                          : AppTheme.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ───────── SUBCATEGORY CHIPS ─────────
  Widget _buildSubcategoryChips() {
    if (_loadingSubcategories) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: SizedBox(
          height: 36,
          child: Center(
            child: SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.getGold(context))),
          ),
        ),
      );
    }
    if (_subcategories.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 36,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _subcategories.length + 1, // +1 for "All" option
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          if (index == 0) {
            final isSelected = _selectedSubcategory == null;
            return GestureDetector(
              onTap: () => setState(() => _selectedSubcategory = null),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.teal.withValues(alpha: 0.15)
                      : AppTheme.getBgGlass(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.teal.withValues(alpha: 0.4)
                        : AppTheme.getBorder(context),
                  ),
                ),
                child: Text(tr('catAll'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? AppTheme.teal : AppTheme.getTextSecondary(context),
                    )),
              ),
            );
          }
          final sub = _subcategories[index - 1];
          final isSelected = _selectedSubcategory == sub;
          return GestureDetector(
            onTap: () => setState(() => _selectedSubcategory = isSelected ? null : sub),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.teal.withValues(alpha: 0.15)
                    : AppTheme.getBgGlass(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.teal.withValues(alpha: 0.4)
                      : AppTheme.getBorder(context),
                ),
              ),
              child: Text(sub,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppTheme.teal : AppTheme.getTextSecondary(context),
                  )),
            ),
          );
        },
      ),
    );
  }

  // ───────── STYLE COUNT ─────────
  Widget _buildStyleCount() {
    if (_loadingStyles || _stylesError != null) return const SizedBox.shrink();
    final count = _filteredStyles.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        '$count ${tr('stylesCount')}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppTheme.getTextTertiary(context),
        ),
      ),
    );
  }

  // ───────── STYLE GRID ─────────
  Widget _buildStyleGrid() {
    // Loading state
    if (_loadingStyles) {
      return SizedBox(
        height: 200,
        child: Center(
          child: CircularProgressIndicator(
            color: AppTheme.getGold(context),
            strokeWidth: 2,
          ),
        ),
      );
    }

    // Error state with retry
    if (_stylesError != null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 30),
        decoration: BoxDecoration(
          color: AppTheme.getBgSecondary(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.getBorder(context)),
        ),
        child: Column(
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 48,
                color: AppTheme.getTextTertiary(context)),
            const SizedBox(height: 16),
            Text(
              _stylesError!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.getTextSecondary(context),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                setState(() {
                  _loadingStyles = true;
                  _stylesError = null;
                });
                _fetchStyles();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.getGoldDim(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppTheme.getGold(context).withValues(alpha: 0.3)),
                ),
                child: Text(tr('retry'),
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.getGold(context))),
              ),
            ),
          ],
        ),
      );
    }

    final styles = _filteredStyles;

    if (styles.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 30),
        decoration: BoxDecoration(
          color: AppTheme.getBgSecondary(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.getBorder(context)),
        ),
        child: Column(
          children: [
            Icon(Icons.content_cut_rounded,
                size: 48,
                color: AppTheme.getTextTertiary(context)),
            const SizedBox(height: 16),
            Text(
              tr('noStylesYet'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.getTextSecondary(context),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: _isTablet
            ? const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.72,
              )
            : const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.72,
              ),
        itemCount: styles.length,
        itemBuilder: (context, index) {
          final style = styles[index];
          final styleId = style['id']?.toString() ?? '';
          final isSelected = _selectedStyle != null &&
              (_selectedStyle!['id']?.toString() ?? '') == styleId;
          final imageUrl = ApiClient.getImageUrl(style['imageUrl']?.toString() ?? style['image']?.toString());
          final styleName = style['name']?.toString() ?? '';
          final stylePrice = style['price']?.toString() ?? '';
          final styleCategory = _effectiveCategory(style).toLowerCase();
          final styleSubcategory = style['subcategory']?.toString();
          final isFeaturedStyle = style['isFeatured'] == true;

          return GestureDetector(
            onTap: _isGenerating
                ? null
                : () {
                    setState(() {
                      _selectedStyle = isSelected ? null : style;
                    });
                    // If photo ready and style just selected, generate
                    if (!isSelected && _hasPhoto) {
                      _generateTryOn();
                    } else if (!isSelected && !_hasPhoto) {
                      _showImageSourceDialog();
                    }
                  },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: isSelected
                    ? Border.all(color: AppTheme.teal, width: 2.5)
                    : Border.all(
                        color: AppTheme.getBorder(context)
                            .withValues(alpha: 0.3)),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppTheme.teal.withValues(alpha: 0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Style image from backend
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: AppTheme.getBgSecondary(context),
                      child: Icon(Icons.image_not_supported_outlined,
                          color: AppTheme.getTextTertiary(context),
                          size: 40),
                    ),
                  ),

                  // Loading overlay when generating this style
                  if (_isGenerating && isSelected)
                    Container(
                      color: Colors.black.withValues(alpha: 0.5),
                      child: const Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppTheme.teal,
                          ),
                        ),
                      ),
                    ),

                  // Bottom info gradient
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 30, 12, 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.85),
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(styleName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 3),
                          Text('$stylePrice ${tr('fcfa')}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.teal.withValues(alpha: 0.9),
                              )),
                        ],
                      ),
                    ),
                  ),

                  // Category badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Row(
                      children: [
                        if (isFeaturedStyle)
                          Container(
                            padding: const EdgeInsets.all(4),
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(Icons.star_rounded, size: 14, color: AppTheme.getGold(context)),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            styleSubcategory != null && styleSubcategory.isNotEmpty
                                ? '${_categoryLabel(styleCategory)} / $styleSubcategory'
                                : _categoryLabel(styleCategory),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Try button
                  if (!isSelected)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.teal,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(tr('try'),
                            style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.bgPrimary)),
                      ),
                    ),

                  // Selected check
                  if (isSelected && !_isGenerating)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppTheme.teal,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.teal.withValues(alpha: 0.4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.check_rounded,
                            color: AppTheme.bgPrimary, size: 16),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────
//  Reusable widgets
// ─────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.getBgGlass(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.getBorder(context)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppTheme.getTextSecondary(context)),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.getTextSecondary(context))),
          ],
        ),
      ),
    );
  }
}

class _SourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: AppTheme.getBgGlass(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.getBorder(context)),
        ),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppTheme.getGoldDim(context),
                borderRadius: BorderRadius.circular(14),
              ),
              child:
                  Icon(icon, color: AppTheme.getGold(context), size: 24),
            ),
            const SizedBox(height: 10),
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.getTextPrimary(context))),
          ],
        ),
      ),
    );
  }
}

/// Clips the child to show only the left portion up to [width].
class _LeftClipper extends CustomClipper<Rect> {
  final double width;
  _LeftClipper(this.width);

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, width, size.height);

  @override
  bool shouldReclip(_LeftClipper oldClipper) => oldClipper.width != width;
}
