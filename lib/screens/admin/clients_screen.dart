import 'package:flutter/material.dart';
import '../../l10n/app_locale.dart';
import '../../services/admin_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gold_button.dart';
import 'client_detail_screen.dart';

/// Salon-scoped client roster — search, scroll, tap into the detail.
class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<Map<String, dynamic>> _clients = [];
  int _page = 1;
  int _totalPages = 1;
  bool _loading = false;
  bool _appending = false;
  String? _error;
  String _searchTerm = '';

  // Debounce search input so we don't hammer the API.
  String _lastIssuedSearch = '';

  @override
  void initState() {
    super.initState();
    _fetch(reset: true);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      if (!_appending && _page < _totalPages) {
        _fetch(reset: false);
      }
    }
  }

  Future<void> _fetch({required bool reset}) async {
    setState(() {
      if (reset) {
        _loading = true;
        _error = null;
        _page = 1;
      } else {
        _appending = true;
      }
    });
    try {
      final pageToFetch = reset ? 1 : _page + 1;
      final res = await AdminService.instance.getLoyaltyClients(
        page: pageToFetch,
        limit: 20,
        search: _searchTerm.isEmpty ? null : _searchTerm,
      );
      final data = (res['data'] ?? res) as Map<String, dynamic>;
      final items = (data['clients'] ?? data['items'] ?? data['data'] ?? []) as List;
      final total = (data['totalPages'] ?? data['pages'] ?? 1) as int;
      final fetched = List<Map<String, dynamic>>.from(items.whereType<Map>());

      if (!mounted) return;
      setState(() {
        if (reset) {
          _clients = fetched;
        } else {
          _clients = [..._clients, ...fetched];
        }
        _page = pageToFetch;
        _totalPages = total;
        _loading = false;
        _appending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _appending = false;
        _error = e.toString();
      });
    }
  }

  void _onSearchChanged(String value) {
    final term = value.trim();
    _searchTerm = term;
    _lastIssuedSearch = term;
    // Tiny debounce — wait 300ms, then if the term is still the latest, fetch.
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      if (_lastIssuedSearch != term) return;
      _fetch(reset: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBgPrimary(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.getTextPrimary(context)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Clients',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.getTextPrimary(context),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearch(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.getBgGlass(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.getBorder(context)),
        ),
        child: TextField(
          controller: _searchCtrl,
          onChanged: _onSearchChanged,
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.getTextPrimary(context),
          ),
          decoration: InputDecoration(
            hintText: 'Search by name or phone',
            hintStyle: TextStyle(
              fontSize: 14,
              color: AppTheme.getTextTertiary(context),
            ),
            prefixIcon: Icon(Icons.search,
                color: AppTheme.getTextTertiary(context), size: 20),
            suffixIcon: _searchCtrl.text.isEmpty
                ? null
                : IconButton(
                    icon: Icon(Icons.close,
                        color: AppTheme.getTextTertiary(context), size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      _onSearchChanged('');
                    },
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(
          color: AppTheme.getGold(context),
          strokeWidth: 2,
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  color: AppTheme.accentRed, size: 36),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.getTextSecondary(context))),
              const SizedBox(height: 16),
              GoldButton(text: tr('retry'), onPressed: () => _fetch(reset: true)),
            ],
          ),
        ),
      );
    }
    if (_clients.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people_outline,
                  color: AppTheme.getTextTertiary(context), size: 42),
              const SizedBox(height: 12),
              Text(
                _searchTerm.isEmpty
                    ? 'No clients yet. They\'ll appear here as soon as someone books.'
                    : 'No matches for "$_searchTerm".',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.getTextSecondary(context),
                    height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetch(reset: true),
      color: AppTheme.getGold(context),
      child: ListView.builder(
        controller: _scrollCtrl,
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: _clients.length + (_appending ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= _clients.length) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.getGold(context)),
                ),
              ),
            );
          }
          return _clientTile(_clients[i]);
        },
      ),
    );
  }

  Widget _clientTile(Map<String, dynamic> c) {
    final id = c['id']?.toString() ?? '';
    final name = (c['clientName'] ?? c['name'] ?? '').toString();
    final phone = (c['clientPhone'] ?? c['phone'] ?? '').toString();
    final points = c['points'] ?? 0;
    final tier = (c['tier'] ?? 'bronze').toString();
    final visits = c['visits'] ?? 0;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          if (id.isEmpty) return;
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ClientDetailScreen(clientId: id),
            ),
          );
          // Refresh in case points were awarded.
          if (mounted) _fetch(reset: true);
        },
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppTheme.getGoldDim(context),
              child: Text(
                _initials(name, phone),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.getGold(context),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? phone : name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.getTextPrimary(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (name.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      phone,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.getTextSecondary(context),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _tierChip(tier),
                      const SizedBox(width: 8),
                      Text(
                        '$visits ${visits == 1 ? "visit" : "visits"}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.getTextTertiary(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$points',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.getGold(context),
                  ),
                ),
                Text(
                  'points',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tierChip(String tier) {
    final color = _tierColor(tier);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        tier.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Color _tierColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'platinum':
        return Colors.purple.shade400;
      case 'gold':
        return Colors.amber.shade700;
      case 'silver':
        return Colors.blueGrey.shade400;
      case 'bronze':
      default:
        return Colors.brown.shade400;
    }
  }

  String _initials(String name, String phone) {
    if (name.isNotEmpty) {
      final parts = name.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        return (parts[0][0] + parts[1][0]).toUpperCase();
      }
      return parts[0][0].toUpperCase();
    }
    if (phone.isNotEmpty) {
      final digits = phone.replaceAll(RegExp(r'\D'), '');
      if (digits.isNotEmpty) return digits.substring(digits.length - 2);
    }
    return '?';
  }
}
