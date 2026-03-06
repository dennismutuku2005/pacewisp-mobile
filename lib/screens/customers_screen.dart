import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  
  List<dynamic> _customers = [];
  int _page = 1;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _search = '';
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _fetchMoreCustomers();
      }
    }
  }

  Future<void> _fetchCustomers() async {
    setState(() => _isLoading = true);
    final res = await _apiService.getCustomers(search: _search, page: 1);
    if (mounted) {
      setState(() {
        _customers = res?['data'] ?? [];
        _hasMore = res?['pagination']?['has_more'] ?? false;
        _total = res?['pagination']?['total'] ?? 0;
        _page = 1;
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchMoreCustomers() async {
    setState(() => _isLoadingMore = true);
    final nextPage = _page + 1;
    final res = await _apiService.getCustomers(search: _search, page: nextPage);
    if (mounted) {
      setState(() {
        final newItems = res?['data'] ?? [];
        _customers.addAll(newItems);
        _hasMore = res?['pagination']?['has_more'] ?? false;
        _page = nextPage;
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        _buildSearchBox(),
        Expanded(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: PaceColors.purple))
            : RefreshIndicator(
                onRefresh: _fetchCustomers,
                color: PaceColors.purple,
                child: ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _customers.length + (_isLoadingMore ? 1 : 0),
                  separatorBuilder: (_, __) => const Divider(color: PaceColors.border, height: 1),
                  itemBuilder: (context, index) {
                    if (index == _customers.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: CircularProgressIndicator(color: PaceColors.purple, strokeWidth: 2)),
                      );
                    }
                    return _buildCustomerItem(_customers[index]);
                  },
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'CUSTOMERS',
                style: TextStyle(color: PaceColors.purple, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: PaceColors.purpleLight, borderRadius: BorderRadius.circular(8)),
                child: Text('TOTAL: $_total', style: const TextStyle(color: PaceColors.purple, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Text(
            'MANAGE HOTSPOT USERS',
            style: TextStyle(color: PaceColors.adminDim, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          color: PaceColors.bgSubtle,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PaceColors.border),
        ),
        child: TextField(
          onChanged: (val) {
            setState(() => _search = val);
            _fetchCustomers();
          },
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(
            hintText: 'Search mobile number or MAC...',
            hintStyle: TextStyle(color: PaceColors.adminDim, fontSize: 12),
            prefixIcon: Icon(Icons.search, color: PaceColors.adminDim, size: 20),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerItem(dynamic customer) {
    final bool isActive = customer['status'] == 'Active';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: PaceColors.bgSubtle,
            child: Icon(Icons.person, color: PaceColors.adminDim, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer['phone'] ?? '',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: PaceColors.purple, fontFamily: 'monospace'),
                ),
                Text(
                  '${customer['mac']?.toString().toUpperCase() ?? ''} • SESSIONS: ${customer['sessions']}',
                  style: const TextStyle(fontSize: 9, color: PaceColors.adminDim, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'KES ${customer['totalSpent']}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: PaceColors.adminValue),
              ),
              const SizedBox(height: 4),
              PaceBadge(
                label: customer['status'] ?? 'Unknown',
                variant: isActive ? BadgeVariant.success : BadgeVariant.error,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
