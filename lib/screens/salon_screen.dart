import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../l10n/app_locale.dart';
import '../services/api_client.dart';
import '../services/customer_service.dart';
import '../services/storage_service.dart';


class SalonScreen extends StatefulWidget {
  final bool isSelector;
  final VoidCallback? onSalonSelected;

  const SalonScreen({super.key, this.isSelector = false, this.onSalonSelected});

  @override
  State<SalonScreen> createState() => _SalonScreenState();
}

class _SalonScreenState extends State<SalonScreen> {
  final _searchController = TextEditingController();
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _salons = [];
  Map<String, dynamic>? _selectedSalon;

  @override
  void initState() {
    super.initState();
    _fetchSalons();
    _fetchSelectedSalon();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchSalons({String? search}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final query = <String, String>{};
      if (search != null && search.isNotEmpty) query['search'] = search;
      final res = await CustomerService.instance.getSalons(query: query);
      final data = res['salons'] ?? res['data'] ?? res['items'] ?? [];
      if (mounted) {
        setState(() {
          _salons = List<Map<String, dynamic>>.from(data is List ? data : []);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchSelectedSalon() async {
    try {
      final res = await CustomerService.instance.getSelectedSalon();
      final data = res['data'] ?? res;
      if (data is Map<String, dynamic> && data['id'] != null && mounted) {
        setState(() => _selectedSalon = data);
      }
    } catch (_) {
      // No salon selected yet — that's fine
    }
  }

  Future<void> _followSalon(String id) async {
    try {
      await CustomerService.instance.followSalon(id);
      _fetchSalons(search: _searchController.text.trim());
    } catch (_) {}
  }

  Future<void> _unfollowSalon(String id) async {
    try {
      await CustomerService.instance.unfollowSalon(id);
      _fetchSalons(search: _searchController.text.trim());
    } catch (_) {}
  }

  Future<void> _selectSalon(Map<String, dynamic> salon) async {
    final id = salon['id'].toString();
    final name = salon['name']?.toString() ?? '';
    final logoUrl = salon['logoUrl']?.toString();
    try {
      await CustomerService.instance.selectSalon(id);
      await StorageService.instance.saveSelectedSalon(id: id, name: name, logoUrl: logoUrl);
      if (mounted) {
        setState(() => _selectedSalon = salon);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tr("salonSelected")}: $name'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        widget.onSalonSelected?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
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
            if (_selectedSalon != null && !widget.isSelector) _buildCurrentSalon(),
            _buildSearchBar(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.isSelector) ...[
            Text(tr('selectSalon'),
                style: AppTheme.displayFont.copyWith(
                    fontSize: 24, color: AppTheme.getTextPrimary(context))),
            const SizedBox(height: 4),
            Text(tr('selectSalonSub'),
                style: TextStyle(fontSize: 13, color: AppTheme.getTextSecondary(context))),
          ] else ...[
            Text(tr('salons'),
                style: AppTheme.displayFont.copyWith(
                    fontSize: 24, color: AppTheme.getTextPrimary(context))),
            const SizedBox(height: 4),
            Text(tr('browseSalonsSub'),
                style: TextStyle(fontSize: 13, color: AppTheme.getTextSecondary(context))),
          ],
        ],
      ),
    );
  }

  Widget _buildCurrentSalon() {
    final name = _selectedSalon!['name']?.toString() ?? '';
    final location = _selectedSalon!['location']?.toString() ?? '';
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.getGold(context).withValues(alpha: 0.12),
            AppTheme.getGold(context).withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.getGold(context).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.getGold(context).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.store_rounded, color: AppTheme.getGold(context), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('currentSalon'),
                    style: TextStyle(fontSize: 10, color: AppTheme.getGold(context), fontWeight: FontWeight.w600)),
                Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.getTextPrimary(context))),
                if (location.isNotEmpty)
                  Text(location, style: TextStyle(fontSize: 11, color: AppTheme.getTextSecondary(context))),
              ],
            ),
          ),
          Icon(Icons.check_circle, color: AppTheme.accentGreen, size: 22),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.getBgGlass(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.getBorder(context)),
        ),
        child: TextField(
          controller: _searchController,
          onSubmitted: (v) => _fetchSalons(search: v.trim()),
          style: TextStyle(color: AppTheme.getTextPrimary(context), fontSize: 14),
          decoration: InputDecoration(
            hintText: tr('searchSalons'),
            hintStyle: TextStyle(color: AppTheme.getTextTertiary(context), fontSize: 14),
            prefixIcon: Icon(Icons.search, color: AppTheme.getTextTertiary(context), size: 20),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: AppTheme.getGold(context), strokeWidth: 2));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: AppTheme.getTextTertiary(context)),
            const SizedBox(height: 12),
            Text(tr('failedToLoadSalons'), style: TextStyle(color: AppTheme.getTextSecondary(context))),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _fetchSalons(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.getGoldDim(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(tr('retry'), style: TextStyle(color: AppTheme.getGold(context), fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      );
    }
    if (_salons.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store_mall_directory_outlined, size: 48, color: AppTheme.getTextTertiary(context)),
            const SizedBox(height: 12),
            Text(tr('noSalonsFound'), style: TextStyle(color: AppTheme.getTextSecondary(context))),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _fetchSalons(search: _searchController.text.trim()),
      color: AppTheme.getGold(context),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _salons.length,
        itemBuilder: (context, index) => _buildSalonCard(_salons[index]),
      ),
    );
  }

  Widget _buildSalonCard(Map<String, dynamic> salon) {
    final id = salon['id']?.toString() ?? '';
    final name = salon['name']?.toString() ?? '';
    final location = salon['location']?.toString() ?? '';
    final rating = (salon['rating'] ?? 0).toString();
    final followers = salon['followersCount']?.toString() ?? '0';
    final isFollowing = salon['isFollowing'] == true;
    final logoUrl = ApiClient.getImageUrl(salon['logoUrl']?.toString());
    final coverUrl = ApiClient.getImageUrl(salon['coverImageUrl']?.toString());
    final isCurrentSalon = _selectedSalon != null && _selectedSalon!['id']?.toString() == id;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.getBgGlass(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentSalon
              ? AppTheme.getGold(context).withValues(alpha: 0.4)
              : AppTheme.getBorder(context),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover image
          SizedBox(
            height: 120,
            width: double.infinity,
            child: coverUrl.isNotEmpty
                ? Image.network(coverUrl, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppTheme.getGoldDim(context),
                      child: Icon(Icons.store, size: 40, color: AppTheme.getGold(context)),
                    ))
                : Container(
                    color: AppTheme.getGoldDim(context),
                    child: Icon(Icons.store, size: 40, color: AppTheme.getGold(context)),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Logo
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.getBorder(context)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: logoUrl.isNotEmpty
                          ? Image.network(logoUrl, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(Icons.store, color: AppTheme.getTextTertiary(context)))
                          : Icon(Icons.store, color: AppTheme.getTextTertiary(context)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.getTextPrimary(context))),
                          if (location.isNotEmpty)
                            Text(location, style: TextStyle(fontSize: 11, color: AppTheme.getTextSecondary(context)), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Rating + followers
                Row(
                  children: [
                    Icon(Icons.star_rounded, size: 16, color: AppTheme.getGold(context)),
                    const SizedBox(width: 4),
                    Text(rating, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.getTextPrimary(context))),
                    const SizedBox(width: 14),
                    Icon(Icons.people_outline, size: 15, color: AppTheme.getTextSecondary(context)),
                    const SizedBox(width: 4),
                    Text('$followers ${tr("followers")}',
                        style: TextStyle(fontSize: 11, color: AppTheme.getTextSecondary(context))),
                    if (isCurrentSalon) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(tr('active'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.accentGreen)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => isFollowing ? _unfollowSalon(id) : _followSalon(id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isFollowing
                                ? AppTheme.getBgGlass(context)
                                : AppTheme.getGold(context).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isFollowing
                                  ? AppTheme.getBorder(context)
                                  : AppTheme.getGold(context).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              isFollowing ? tr('following') : tr('follow'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isFollowing ? AppTheme.getTextSecondary(context) : AppTheme.getGold(context),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: isCurrentSalon ? null : () => _selectSalon(salon),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isCurrentSalon
                                ? AppTheme.accentGreen.withValues(alpha: 0.12)
                                : AppTheme.getGold(context),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              isCurrentSalon ? tr('selected') : tr('useSalon'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isCurrentSalon ? AppTheme.accentGreen : AppTheme.getBgPrimary(context),
                              ),
                            ),
                          ),
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
    );
  }
}
