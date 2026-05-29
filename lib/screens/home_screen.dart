import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../l10n/app_locale.dart';
import '../widgets/glass_card.dart';
import '../services/api_client.dart';
import '../services/customer_service.dart';
import '../services/storage_service.dart';
import 'salon_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function(int) onTabSwitch;
  const HomeScreen({super.key, required this.onTabSwitch});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Function(int) get onTabSwitch => widget.onTabSwitch;

  // Feed state
  List<Map<String, dynamic>> _cards = [];
  int _page = 1;
  bool _hasMore = true;
  bool _isLoadingFeed = true;
  bool _isLoadingMore = false;
  String? _feedError;

  // User
  String _userName = '';

  // Salon
  bool _hasSalon = false;
  String? _salonName;

  // Upcoming booking
  Map<String, dynamic>? _upcomingBooking;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _hasSalon = StorageService.instance.hasSalonSelected;
    _salonName = StorageService.instance.selectedSalonName;
    _scrollController.addListener(_onScroll);
    _fetchProfile();
    _syncSelectedSalon();
    _loadFeed(1);
    if (_hasSalon) _fetchUpcomingBooking();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadFeed(_page + 1);
    }
  }

  /// Sync selected salon from backend — persists locally so it survives restarts
  Future<void> _syncSelectedSalon() async {
    try {
      final res = await CustomerService.instance.getSelectedSalon();
      final data = res['data'] ?? res;
      if (data is Map<String, dynamic> && data['id'] != null && mounted) {
        final id = data['id'].toString();
        final name = data['name']?.toString() ?? '';
        final logoUrl = data['logoUrl']?.toString();
        await StorageService.instance.saveSelectedSalon(id: id, name: name, logoUrl: logoUrl);
        setState(() {
          _hasSalon = true;
          _salonName = name;
        });
        _fetchUpcomingBooking();
      }
    } catch (_) {
      // No salon selected on backend — keep local state as-is
    }
  }

  Future<void> _fetchProfile() async {
    try {
      final response = await CustomerService.instance.getProfile();
      final data = response['data'] ?? response;
      if (mounted) {
        setState(() => _userName = data['name']?.toString() ?? data['fullName']?.toString() ?? '');
      }
    } catch (_) {}
  }

  Future<void> _loadFeed(int pageNum) async {
    if (pageNum == 1) {
      setState(() { _isLoadingFeed = true; _feedError = null; });
    } else {
      if (_isLoadingMore) return;
      setState(() => _isLoadingMore = true);
    }

    try {
      final response = await CustomerService.instance.getExploreFeed(page: pageNum);
      final data = response['data'] ?? response;
      final newCards = data['cards'] as List? ?? [];
      final hasMore = data['hasMore'] == true;
      final page = data['page'] as int? ?? pageNum;

      if (mounted) {
        setState(() {
          if (pageNum == 1) {
            _cards = List<Map<String, dynamic>>.from(newCards);
          } else {
            _cards.addAll(List<Map<String, dynamic>>.from(newCards));
          }
          _page = page;
          _hasMore = hasMore;
          _isLoadingFeed = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _feedError = e.toString();
          _isLoadingFeed = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _refreshFeed() async {
    await Future.wait([
      _fetchProfile(),
      _loadFeed(1),
    ]);
    if (_hasSalon) _fetchUpcomingBooking();
  }

  Future<void> _fetchUpcomingBooking() async {
    try {
      final res = await CustomerService.instance.getMyBookings(query: {'status': 'confirmed', 'limit': '1'});
      final data = res['data'] ?? res;
      final items = data['items'] ?? data['bookings'] ?? (data is List ? data : []);
      if (items is List && items.isNotEmpty && mounted) {
        setState(() => _upcomingBooking = Map<String, dynamic>.from(items.first));
      }
    } catch (_) {}
  }

  void _openSalonSelector() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SalonScreen(
          isSelector: true,
          onSalonSelected: () {
            Navigator.of(context).pop();
            setState(() {
              _hasSalon = true;
              _salonName = StorageService.instance.selectedSalonName;
            });
            _fetchUpcomingBooking();
          },
        ),
      ),
    );
  }

  /// Opens the daily tip detail in a draggable bottom sheet
  void _showTipDetail(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _TipDetailSheet(data: data),
    );
  }

  /// Opens the inspiration detail in a draggable bottom sheet
  void _showInspirationDetail(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _InspirationDetailSheet(
        data: data,
        onStyleTap: () {
          Navigator.pop(context);
          onTabSwitch(1);
        },
      ),
    );
  }

  /// Shows a bottom sheet with followed salons for quick switching
  void _showSalonSwitcher() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _SalonSwitcherSheet(
        currentSalonId: StorageService.instance.selectedSalonId,
        onSelect: (salon) async {
          Navigator.pop(ctx);
          final id = salon['id'].toString();
          final name = salon['name']?.toString() ?? '';
          final logoUrl = salon['logoUrl']?.toString();
          try {
            await CustomerService.instance.selectSalon(id);
            await StorageService.instance.saveSelectedSalon(id: id, name: name, logoUrl: logoUrl);
            if (mounted) {
              setState(() {
                _hasSalon = true;
                _salonName = name;
              });
              _fetchUpcomingBooking();
            }
          } catch (_) {}
        },
        onBrowseMore: () {
          Navigator.pop(ctx);
          _openSalonSelector();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refreshFeed,
      color: AppTheme.getGold(context),
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          // ── Fixed header section ──
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                _buildHeader(),
                _buildGreeting(),
                if (!_hasSalon) _buildSalonPrompt(),
                if (_hasSalon && _upcomingBooking != null) _buildUpcomingBooking(),
              ],
            ),
          ),

          // ── Loading state ──
          if (_isLoadingFeed && _cards.isEmpty)
            SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: AppTheme.getGold(context), strokeWidth: 2)),
            ),

          // ── Error state ──
          if (!_isLoadingFeed && _cards.isEmpty && _feedError != null)
            SliverFillRemaining(child: _buildErrorState()),

          // ── Feed cards ──
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index < _cards.length) {
                  return _buildCard(_cards[index]);
                }
                // Loading more indicator
                if (_isLoadingMore) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator(color: AppTheme.getGold(context), strokeWidth: 2)),
                  );
                }
                return null;
              },
              childCount: _cards.length + (_isLoadingMore ? 1 : 0),
            ),
          ),

          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────
  //  Card router — renders by type
  // ───────────────────────────────────────────
  Widget _buildCard(Map<String, dynamic> card) {
    final type = card['type']?.toString() ?? '';
    final data = card['data'] as Map<String, dynamic>? ?? card;

    return switch (type) {
      'sotd' => _buildSOTD(data),
      'collection' => _buildCollection(data),
      'tip' => _buildTip(data),
      'trending' => _buildTrending(data),
      'inspiration' => _buildInspiration(data),
      'community_tryon' => _buildCommunity(data),
      'style' => _buildStyleCard(data),
      _ => const SizedBox.shrink(),
    };
  }

  // ───────────────────────────────────────────
  //  1. SOTD — Hero card
  // ───────────────────────────────────────────
  Widget _buildSOTD(Map<String, dynamic> data) {
    final style = data['style'] as Map<String, dynamic>? ?? {};
    final caption = data['caption']?.toString() ?? '';
    final imageUrl = ApiClient.getImageUrl(style['imageUrl']?.toString() ?? '');
    final name = style['name']?.toString() ?? '';
    final rating = style['avgRating'];
    final tryOnCount = style['tryOnCount'];

    return GestureDetector(
      onTap: () => onTabSwitch(1),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: AppTheme.getBgSecondary(context),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl.isNotEmpty)
              Image.network(imageUrl, fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(color: AppTheme.getBgSecondary(context))),
            // Strong gradient for text readability
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0x40000000), Color(0xDD000000), Color(0xF0000000)],
                  stops: [0.0, 0.35, 0.75, 1.0],
                ),
              ),
            ),
            // Content
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: AppTheme.displayFont.copyWith(fontSize: 22, color: Colors.white,
                            shadows: const [Shadow(offset: Offset(0, 1), blurRadius: 4, color: Colors.black)])),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(caption,
                              style: const TextStyle(fontSize: 12, color: Colors.white,
                                  shadows: [Shadow(offset: Offset(0, 1), blurRadius: 3, color: Colors.black)]),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        if (rating != null) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.star_rounded, size: 14, color: AppTheme.getGold(context)),
                          const SizedBox(width: 2),
                          Text('$rating', style: TextStyle(fontSize: 11, color: AppTheme.getGold(context), fontWeight: FontWeight.w700)),
                        ],
                        if (tryOnCount != null && tryOnCount > 0) ...[
                          const SizedBox(width: 8),
                          Text('$tryOnCount ${tr("tryOns")}', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Try it button
            Positioned(
              top: 14, right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: AppTheme.getGold(context),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 2))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_fix_high, size: 14, color: AppTheme.getBgPrimary(context)),
                    const SizedBox(width: 4),
                    Text(tr('tryIt'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.getBgPrimary(context))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────
  //  2. Collection — horizontal scroll row
  // ───────────────────────────────────────────
  Widget _buildCollection(Map<String, dynamic> data) {
    final title = data['title']?.toString() ?? '';
    final styles = data['styles'] as List? ?? [];
    if (styles.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(title, style: AppTheme.displayFont.copyWith(fontSize: 17, color: AppTheme.getTextPrimary(context)),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              Text(tr('seeAll'), style: TextStyle(fontSize: 12, color: AppTheme.getGold(context), fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        SizedBox(
          height: 170,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: styles.length,
            itemBuilder: (context, index) {
              final s = styles[index] as Map<String, dynamic>? ?? {};
              final sName = s['name']?.toString() ?? '';
              final sImg = ApiClient.getImageUrl(s['imageUrl']?.toString() ?? '');
              final sPrice = s['price']?.toString() ?? '';
              final sRating = s['avgRating'];

              return GestureDetector(
                onTap: () => onTabSwitch(1),
                child: Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.getBorder(context)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            sImg.isNotEmpty
                                ? Image.network(sImg, fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Container(color: AppTheme.getBgGlass(context)))
                                : Container(color: AppTheme.getBgGlass(context)),
                            if (sRating != null)
                              Positioned(
                                top: 6, right: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(5)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.star_rounded, size: 10, color: AppTheme.getGold(context)),
                                      const SizedBox(width: 2),
                                      Text('$sRating', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(sName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.getTextPrimary(context)),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (sPrice.isNotEmpty)
                        Text('$sPrice ${tr("fcfa")}', style: TextStyle(fontSize: 10, color: AppTheme.getGold(context), fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────
  //  3. Tip — article card
  // ───────────────────────────────────────────
  Widget _buildTip(Map<String, dynamic> data) {
    final title = data['title']?.toString() ?? '';
    final body = data['body']?.toString() ?? data['content']?.toString() ?? '';
    final coverUrl = ApiClient.getImageUrl(data['coverImageUrl']?.toString() ?? data['imageUrl']?.toString() ?? '');

    return GestureDetector(
      onTap: () => _showTipDetail(data),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        decoration: BoxDecoration(
          color: AppTheme.getBgGlass(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.getBorder(context)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (coverUrl.isNotEmpty)
              SizedBox(
                width: 90, height: 100,
                child: Image.network(coverUrl, fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(color: AppTheme.getBgGlass(context),
                        child: Icon(Icons.lightbulb_outline, size: 28, color: AppTheme.getTextTertiary(context)))),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('dailyTip'), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                        color: AppTheme.getTextTertiary(context), letterSpacing: 0.3)),
                    const SizedBox(height: 4),
                    Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.getTextPrimary(context)),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(body, style: TextStyle(fontSize: 12, color: AppTheme.getTextSecondary(context), height: 1.4),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(tr('readMore'),
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.getGold(context))),
                        const SizedBox(width: 2),
                        Icon(Icons.chevron_right, size: 14, color: AppTheme.getGold(context)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────
  //  4. Trending — horizontal scroll
  // ───────────────────────────────────────────
  Widget _buildTrending(Map<String, dynamic> data) {
    final title = data['title']?.toString() ?? tr('trendingNow');
    final styles = data['styles'] as List? ?? [];
    if (styles.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: AppTheme.displayFont.copyWith(fontSize: 18, color: AppTheme.getTextPrimary(context))),
              GestureDetector(
                onTap: () => onTabSwitch(1),
                child: Text(tr('seeAll'), style: TextStyle(fontSize: 12, color: AppTheme.getGold(context), fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 230,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: styles.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final s = styles[index] as Map<String, dynamic>? ?? {};
              final name = s['name']?.toString() ?? '';
              final imageUrl = ApiClient.getImageUrl(s['imageUrl']?.toString() ?? '');
              final tryOnCount = s['tryOnCount'];
              final avgRating = s['avgRating'];

              return GestureDetector(
                onTap: () => onTabSwitch(1),
                child: SizedBox(
                  width: 140,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.network(imageUrl, width: 140, height: 175, fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(width: 140, height: 175,
                                    decoration: BoxDecoration(color: AppTheme.getBgGlass(context), borderRadius: BorderRadius.circular(14)),
                                    child: Icon(Icons.image_not_supported, color: AppTheme.getTextTertiary(context)))),
                          ),
                          if (avgRating != null)
                            Positioned(top: 8, right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(Icons.star_rounded, size: 12, color: AppTheme.getGold(context)),
                                  const SizedBox(width: 2),
                                  Text('$avgRating', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
                                ]),
                              ),
                            ),
                          if (tryOnCount != null && tryOnCount > 0)
                            Positioned(top: 8, left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(color: AppTheme.getGold(context).withValues(alpha: 0.9), borderRadius: BorderRadius.circular(6)),
                                child: Text('$tryOnCount ${tr("tryOns")}',
                                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.getTextPrimary(context))),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────
  //  5. Inspiration — mood board card
  // ───────────────────────────────────────────
  Widget _buildInspiration(Map<String, dynamic> data) {
    final title = data['title']?.toString() ?? '';
    final body = data['body']?.toString() ?? data['description']?.toString() ?? '';
    final coverUrl = ApiClient.getImageUrl(data['coverImageUrl']?.toString() ?? data['imageUrl']?.toString() ?? '');
    final linkedStyles = data['linkedStyles'] as List? ?? data['styles'] as List? ?? [];
    final tags = data['tags'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tr('inspiration'), style: AppTheme.displayFont.copyWith(fontSize: 17, color: AppTheme.getTextPrimary(context))),
              GestureDetector(
                onTap: () => _showInspirationDetail(data),
                child: Row(
                  children: [
                    Text(tr('readMore'),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.getGold(context))),
                    Icon(Icons.chevron_right, size: 16, color: AppTheme.getGold(context)),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (coverUrl.isNotEmpty)
          GestureDetector(
            onTap: () => _showInspirationDetail(data),
            child: Container(
              margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              height: 170,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(coverUrl, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(color: AppTheme.getBgGlass(context))),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xBB000000)],
                        stops: [0.4, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 14, left: 14, right: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white,
                            shadows: [Shadow(offset: Offset(0, 1), blurRadius: 3, color: Colors.black)]),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        if (body.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(body, style: const TextStyle(fontSize: 11, color: Colors.white70), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ],
                    ),
                  ),
                  Positioned(
                    top: 10, right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.open_in_full_rounded, size: 11, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(tr('readMore'),
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Wrap(
              spacing: 6,
              children: tags.take(4).map((t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppTheme.getBgGlass(context), borderRadius: BorderRadius.circular(6)),
                child: Text(t.toString(), style: TextStyle(fontSize: 10, color: AppTheme.getTextSecondary(context))),
              )).toList(),
            ),
          ),
        if (linkedStyles.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 100,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: linkedStyles.length,
              itemBuilder: (context, index) {
                final s = linkedStyles[index] as Map<String, dynamic>? ?? {};
                final sName = s['name']?.toString() ?? '';
                final sImg = ApiClient.getImageUrl(s['imageUrl']?.toString() ?? '');
                return GestureDetector(
                  onTap: () => onTabSwitch(1),
                  child: Container(
                    width: 72, margin: const EdgeInsets.only(right: 10),
                    child: Column(
                      children: [
                        Container(
                          width: 64, height: 64,
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.getBorder(context))),
                          clipBehavior: Clip.antiAlias,
                          child: sImg.isNotEmpty
                              ? Image.network(sImg, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: AppTheme.getBgGlass(context)))
                              : Container(color: AppTheme.getBgGlass(context)),
                        ),
                        const SizedBox(height: 4),
                        Text(sName, style: TextStyle(fontSize: 9, color: AppTheme.getTextSecondary(context)),
                            maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  // ───────────────────────────────────────────
  //  6. Community try-ons
  // ───────────────────────────────────────────
  Widget _buildCommunity(Map<String, dynamic> data) {
    final title = data['title']?.toString() ?? tr('communityTryOns');
    final tryOns = data['tryOns'] as List? ?? [];
    if (tryOns.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Row(
            children: [
              Icon(Icons.people_outline, size: 18, color: AppTheme.getTextSecondary(context)),
              const SizedBox(width: 8),
              Text(title, style: AppTheme.displayFont.copyWith(fontSize: 17, color: AppTheme.getTextPrimary(context))),
            ],
          ),
        ),
        SizedBox(
          height: 190,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: tryOns.length,
            itemBuilder: (context, index) {
              final item = tryOns[index] as Map<String, dynamic>? ?? {};
              final imageUrl = ApiClient.getImageUrl(item['generatedImageUrl']?.toString() ?? item['imageUrl']?.toString() ?? '');
              final styleName = item['styleName']?.toString() ?? '';
              final userName = item['customerName']?.toString() ?? '';

              return Container(
                width: 140, margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.getBorder(context))),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    imageUrl.isNotEmpty
                        ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: AppTheme.getBgGlass(context)))
                        : Container(color: AppTheme.getBgGlass(context)),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xBB000000)], stops: [0.5, 1.0],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 10, left: 10, right: 10,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (styleName.isNotEmpty)
                            Text(styleName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          if (userName.isNotEmpty)
                            Text(userName, style: const TextStyle(fontSize: 10, color: Colors.white70), maxLines: 1),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────
  //  7. Style — individual card (infinite scroll)
  // ───────────────────────────────────────────
  Widget _buildStyleCard(Map<String, dynamic> data) {
    final name = data['name']?.toString() ?? '';
    final imageUrl = ApiClient.getImageUrl(data['imageUrl']?.toString() ?? '');
    final price = data['price']?.toString() ?? '';
    final priceMax = data['priceMax']?.toString();
    final rating = data['avgRating'];
    final reviewCount = data['reviewCount'];
    final category = data['category']?.toString() ?? '';
    final isFeatured = data['isFeatured'] == true;

    final priceLabel = (priceMax != null && priceMax != price)
        ? '$price - $priceMax ${tr("fcfa")}'
        : '$price ${tr("fcfa")}';

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      decoration: BoxDecoration(
        color: AppTheme.getBgGlass(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.getBorder(context)),
      ),
      child: Row(
        children: [
          // Image
          Container(
            width: 100, height: 110,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(topLeft: Radius.circular(15), bottomLeft: Radius.circular(15)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                imageUrl.isNotEmpty
                    ? Image.network(imageUrl, fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(color: AppTheme.getBgGlass(context)))
                    : Container(color: AppTheme.getBgGlass(context)),
                if (isFeatured)
                  Positioned(top: 6, left: 6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(5)),
                      child: Icon(Icons.star_rounded, size: 12, color: AppTheme.getGold(context)),
                    ),
                  ),
              ],
            ),
          ),
          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.getTextPrimary(context)),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  if (category.isNotEmpty)
                    Text(category, style: TextStyle(fontSize: 11, color: AppTheme.getTextTertiary(context))),
                  const SizedBox(height: 6),
                  Text(priceLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.getGold(context))),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (rating != null) ...[
                        Icon(Icons.star_rounded, size: 13, color: AppTheme.getGold(context)),
                        const SizedBox(width: 2),
                        Text('$rating', style: TextStyle(fontSize: 11, color: AppTheme.getTextSecondary(context), fontWeight: FontWeight.w500)),
                      ],
                      if (reviewCount != null && reviewCount > 0) ...[
                        const SizedBox(width: 6),
                        Text('($reviewCount)', style: TextStyle(fontSize: 10, color: AppTheme.getTextTertiary(context))),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Try on button
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => onTabSwitch(1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.getGoldDim(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.getGold(context).withValues(alpha: 0.3)),
                ),
                child: Text(tr('tryIt'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.getGold(context))),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────
  //  Fixed header widgets
  // ───────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Image.asset('assets/logo.png', height: 44, fit: BoxFit.contain),
          Row(
            children: [
              GestureDetector(
                onTap: () => AppLocale.instance.toggleLanguage(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: AppTheme.getBgGlass(context), borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.getBorder(context))),
                  child: Text(AppLocale.instance.isEnglish ? 'EN' : 'FR',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.getGold(context), letterSpacing: 0.5)),
                ),
              ),
              const SizedBox(width: 14),
              GestureDetector(
                onTap: () => AppLocale.instance.toggleTheme(),
                child: Icon(AppLocale.instance.isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                    color: AppTheme.getGold(context), size: 22),
              ),
              const SizedBox(width: 14),
              Icon(Icons.notifications_outlined, color: AppTheme.getTextSecondary(context), size: 22),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGreeting() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 14, color: AppTheme.getTextSecondary(context)),
          children: [
            TextSpan(text: tr('goodMorning')),
            if (_userName.isNotEmpty)
              TextSpan(text: _userName, style: TextStyle(color: AppTheme.getTextPrimary(context), fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildSalonPrompt() {
    return GestureDetector(
      onTap: _openSalonSelector,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [AppTheme.accentBlue.withValues(alpha: 0.12), AppTheme.accentBlue.withValues(alpha: 0.04)]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(width: 44, height: 44,
                decoration: BoxDecoration(color: AppTheme.accentBlue.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.store_rounded, color: AppTheme.accentBlue, size: 22)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('connectToSalon'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.getTextPrimary(context))),
              const SizedBox(height: 2),
              Text(tr('connectToSalonSub'), style: TextStyle(fontSize: 11, color: AppTheme.getTextSecondary(context))),
            ])),
            const Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.accentBlue),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingBooking() {
    final b = _upcomingBooking!;
    final styleName = b['styleName']?.toString() ?? b['service']?.toString() ?? tr('appointment');
    final date = b['date']?.toString() ?? '';
    final time = b['time']?.toString() ?? '';
    final status = b['status']?.toString() ?? 'confirmed';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Text(tr('upcoming'), style: AppTheme.displayFont.copyWith(fontSize: 18, color: AppTheme.getTextPrimary(context))),
        ),
        const SizedBox(height: 10),
        GlassCard(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          onTap: () => onTabSwitch(2),
          child: Row(
            children: [
              Container(width: 44, height: 44,
                  decoration: BoxDecoration(color: AppTheme.accentBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.calendar_today, color: AppTheme.accentBlue, size: 20)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(styleName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.getTextPrimary(context))),
                Text('$date · $time', style: TextStyle(fontSize: 11, color: AppTheme.getTextSecondary(context))),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: AppTheme.accentBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(status, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.accentBlue)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded, size: 48, color: AppTheme.getTextTertiary(context)),
          const SizedBox(height: 16),
          Text(tr('failedToLoadStyles'), style: TextStyle(fontSize: 14, color: AppTheme.getTextSecondary(context))),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => _loadFeed(1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.getGoldDim(context), borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.getGold(context).withValues(alpha: 0.3)),
              ),
              child: Text(tr('retry'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.getGold(context))),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet that shows followed salons for quick switching
class _SalonSwitcherSheet extends StatefulWidget {
  final String? currentSalonId;
  final void Function(Map<String, dynamic> salon) onSelect;
  final VoidCallback onBrowseMore;

  const _SalonSwitcherSheet({
    required this.currentSalonId,
    required this.onSelect,
    required this.onBrowseMore,
  });

  @override
  State<_SalonSwitcherSheet> createState() => _SalonSwitcherSheetState();
}

class _SalonSwitcherSheetState extends State<_SalonSwitcherSheet> {
  List<Map<String, dynamic>> _followedSalons = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchFollowed();
  }

  Future<void> _fetchFollowed() async {
    try {
      final res = await CustomerService.instance.getFollowedSalons();
      final raw = res['salons'] ?? res['items'] ?? res['data'] ?? res;
      final data = raw is List ? raw : (raw is Map ? (raw['salons'] ?? raw['items'] ?? []) : []);
      if (data is List && mounted) {
        setState(() {
          _followedSalons = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
      decoration: BoxDecoration(
        color: AppTheme.getBgSecondary(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppTheme.getBorder(context))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(color: AppTheme.getTextTertiary(context), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(tr('switchSalon'),
                    style: AppTheme.displayFont.copyWith(fontSize: 18, color: AppTheme.getTextPrimary(context))),
                GestureDetector(
                  onTap: widget.onBrowseMore,
                  child: Text(tr('browseMore'),
                      style: TextStyle(fontSize: 12, color: AppTheme.getGold(context), fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // List
          if (_loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Center(child: CircularProgressIndicator(color: AppTheme.getGold(context), strokeWidth: 2)),
            )
          else if (_followedSalons.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              child: Column(
                children: [
                  Icon(Icons.store_mall_directory_outlined, size: 36, color: AppTheme.getTextTertiary(context)),
                  const SizedBox(height: 10),
                  Text(tr('noFollowedSalons'), style: TextStyle(fontSize: 13, color: AppTheme.getTextSecondary(context))),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: widget.onBrowseMore,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.getGoldDim(context),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.getGold(context).withValues(alpha: 0.3)),
                      ),
                      child: Text(tr('findSalon'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.getGold(context))),
                    ),
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: _followedSalons.length,
                itemBuilder: (context, index) {
                  final salon = _followedSalons[index];
                  final id = salon['id']?.toString() ?? '';
                  final name = salon['name']?.toString() ?? '';
                  final location = salon['location']?.toString() ?? '';
                  final rating = salon['rating']?.toString();
                  final isCurrent = id == widget.currentSalonId;
                  final logoUrl = ApiClient.getImageUrl(salon['logoUrl']?.toString() ?? '');

                  return GestureDetector(
                    onTap: isCurrent ? null : () => widget.onSelect(salon),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? AppTheme.accentGreen.withValues(alpha: 0.08)
                            : AppTheme.getBgGlass(context),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isCurrent
                              ? AppTheme.accentGreen.withValues(alpha: 0.25)
                              : AppTheme.getBorder(context),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Logo
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.getBorder(context)),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: logoUrl.isNotEmpty
                                ? Image.network(logoUrl, fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Icon(Icons.store, size: 20, color: AppTheme.getTextTertiary(context)))
                                : Icon(Icons.store, size: 20, color: AppTheme.getTextTertiary(context)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.getTextPrimary(context))),
                                if (location.isNotEmpty)
                                  Text(location, style: TextStyle(fontSize: 11, color: AppTheme.getTextSecondary(context)),
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          if (rating != null) ...[
                            Icon(Icons.star_rounded, size: 14, color: AppTheme.getGold(context)),
                            const SizedBox(width: 2),
                            Text(rating, style: TextStyle(fontSize: 11, color: AppTheme.getTextSecondary(context))),
                            const SizedBox(width: 8),
                          ],
                          if (isCurrent)
                            const Icon(Icons.check_circle, color: AppTheme.accentGreen, size: 20)
                          else
                            Icon(Icons.chevron_right, color: AppTheme.getTextTertiary(context), size: 20),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────
//  Daily tip — full detail bottom sheet
// ───────────────────────────────────────────
class _TipDetailSheet extends StatelessWidget {
  final Map<String, dynamic> data;
  const _TipDetailSheet({required this.data});

  @override
  Widget build(BuildContext context) {
    final title = data['title']?.toString() ?? '';
    final body = data['body']?.toString() ?? data['content']?.toString() ?? '';
    final coverUrl = ApiClient.getImageUrl(data['coverImageUrl']?.toString() ?? data['imageUrl']?.toString() ?? '');
    final author = data['author']?.toString() ?? data['authorName']?.toString() ?? '';
    final publishedAt = data['publishedAt']?.toString() ?? data['createdAt']?.toString() ?? '';

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.getBgSecondary(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: AppTheme.getBorder(context))),
          ),
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.getTextTertiary(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    if (coverUrl.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                        height: 200,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
                        clipBehavior: Clip.antiAlias,
                        child: Image.network(coverUrl, fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                                color: AppTheme.getBgGlass(context),
                                child: Icon(Icons.lightbulb_outline, size: 36, color: AppTheme.getTextTertiary(context)))),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.lightbulb_outline, size: 14, color: AppTheme.getGold(context)),
                              const SizedBox(width: 6),
                              Text(tr('dailyTip'),
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                      color: AppTheme.getGold(context), letterSpacing: 0.5)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(title,
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
                                  color: AppTheme.getTextPrimary(context), height: 1.25)),
                          if (author.isNotEmpty || publishedAt.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              [author, publishedAt].where((s) => s.isNotEmpty).join(' • '),
                              style: TextStyle(fontSize: 11, color: AppTheme.getTextTertiary(context)),
                            ),
                          ],
                          if (body.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(body,
                                style: TextStyle(fontSize: 14, height: 1.6, color: AppTheme.getTextSecondary(context))),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ───────────────────────────────────────────
//  Inspiration — full detail bottom sheet
// ───────────────────────────────────────────
class _InspirationDetailSheet extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onStyleTap;
  const _InspirationDetailSheet({required this.data, required this.onStyleTap});

  @override
  Widget build(BuildContext context) {
    final title = data['title']?.toString() ?? '';
    final body = data['body']?.toString() ?? data['description']?.toString() ?? '';
    final coverUrl = ApiClient.getImageUrl(data['coverImageUrl']?.toString() ?? data['imageUrl']?.toString() ?? '');
    final linkedStyles = data['linkedStyles'] as List? ?? data['styles'] as List? ?? [];
    final tags = data['tags'] as List? ?? [];

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.getBgSecondary(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: AppTheme.getBorder(context))),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.getTextTertiary(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    if (coverUrl.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                        height: 240,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
                        clipBehavior: Clip.antiAlias,
                        child: Image.network(coverUrl, fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(color: AppTheme.getBgGlass(context))),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.auto_awesome, size: 14, color: AppTheme.getGold(context)),
                              const SizedBox(width: 6),
                              Text(tr('inspiration'),
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                      color: AppTheme.getGold(context), letterSpacing: 0.5)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(title,
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
                                  color: AppTheme.getTextPrimary(context), height: 1.25)),
                          if (body.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Text(body,
                                style: TextStyle(fontSize: 14, height: 1.6, color: AppTheme.getTextSecondary(context))),
                          ],
                          if (tags.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8, runSpacing: 8,
                              children: tags.map((t) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppTheme.getBgGlass(context),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.getBorder(context)),
                                ),
                                child: Text('#${t.toString()}',
                                    style: TextStyle(fontSize: 11, color: AppTheme.getTextSecondary(context))),
                              )).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (linkedStyles.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                        child: Text(tr('inspiration'),
                            style: AppTheme.displayFont.copyWith(fontSize: 14, color: AppTheme.getTextPrimary(context))),
                      ),
                      SizedBox(
                        height: 140,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          scrollDirection: Axis.horizontal,
                          itemCount: linkedStyles.length,
                          itemBuilder: (context, index) {
                            final s = linkedStyles[index] as Map<String, dynamic>? ?? {};
                            final sName = s['name']?.toString() ?? '';
                            final sImg = ApiClient.getImageUrl(s['imageUrl']?.toString() ?? '');
                            return GestureDetector(
                              onTap: onStyleTap,
                              child: Container(
                                width: 96, margin: const EdgeInsets.only(right: 12),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 96, height: 100,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppTheme.getBorder(context)),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: sImg.isNotEmpty
                                          ? Image.network(sImg, fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) => Container(color: AppTheme.getBgGlass(context)))
                                          : Container(color: AppTheme.getBgGlass(context)),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(sName,
                                        style: TextStyle(fontSize: 11, color: AppTheme.getTextSecondary(context)),
                                        maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                    ] else
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
}
