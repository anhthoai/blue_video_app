import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';

class CoinHistoryScreen extends ConsumerStatefulWidget {
  const CoinHistoryScreen({super.key});

  @override
  ConsumerState<CoinHistoryScreen> createState() => _CoinHistoryScreenState();
}

class _CoinHistoryScreenState extends ConsumerState<CoinHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentPage = 1;
  final int _pageSize = 20;
  bool _isLoading = false;
  bool _hasMore = true;

  // Transaction data for each tab
  List<Map<String, dynamic>> _usedTransactions = [];
  List<Map<String, dynamic>> _earnedTransactions = [];
  List<Map<String, dynamic>> _rechargeTransactions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTransactions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions({bool refresh = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (refresh) {
        _currentPage = 1;
        _usedTransactions.clear();
        _earnedTransactions.clear();
        _rechargeTransactions.clear();
        _hasMore = true;
      }
    });

    try {
      final apiService = ApiService();

      // Load all transaction types
      final usedTxs = await apiService.getCoinTransactions(
        type: 'USED',
        page: _currentPage,
        limit: _pageSize,
      );

      final earnedTxs = await apiService.getCoinTransactions(
        type: 'EARNED',
        page: _currentPage,
        limit: _pageSize,
      );

      final rechargeTxs = await apiService.getCoinTransactions(
        type: 'RECHARGE',
        page: _currentPage,
        limit: _pageSize,
      );

      setState(() {
        _usedTransactions.addAll(usedTxs);
        _earnedTransactions.addAll(earnedTxs);
        _rechargeTransactions.addAll(rechargeTxs);
        _hasMore = usedTxs.length == _pageSize ||
            earnedTxs.length == _pageSize ||
            rechargeTxs.length == _pageSize;
        _currentPage++;
      });
    } catch (e) {
      print('Error loading transactions: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to load transactions: ${e.toString().length > 50 ? e.toString().substring(0, 50) + '...' : e.toString()}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getCurrentTransactions() {
    switch (_tabController.index) {
      case 0:
        return _usedTransactions;
      case 1:
        return _earnedTransactions;
      case 2:
        return _rechargeTransactions;
      default:
        return [];
    }
  }

  String _getTabTitle(int index) {
    switch (index) {
      case 0:
        return 'Used';
      case 1:
        return 'Earned';
      case 2:
        return 'Recharge';
      default:
        return '';
    }
  }

  Color _getTransactionColor(String type) {
    switch (type) {
      case 'USED':
        return Colors.red;
      case 'EARNED':
        return Colors.green;
      case 'RECHARGE':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getTransactionIcon(String type) {
    switch (type) {
      case 'USED':
        return Icons.shopping_cart;
      case 'EARNED':
        return Icons.trending_up;
      case 'RECHARGE':
        return Icons.add_circle;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final userCoinBalance = currentUser?.coinBalance ?? 0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header with gradient background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => context.pop(),
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.white),
                        ),
                        const Expanded(
                          child: Text(
                            'Coin History',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            await _loadTransactions(refresh: true);
                            // Also refresh user balance from server
                            try {
                              await ref
                                  .read(authServiceProvider)
                                  .refreshCurrentUser();
                            } catch (_) {}
                          },
                          icon: const Icon(Icons.refresh, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Current Balance Display
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.monetization_on,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Current Balance: $userCoinBalance coins',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Tab Bar
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF8B5CF6),
                labelColor: const Color(0xFF8B5CF6),
                unselectedLabelColor: Colors.grey,
                tabs: const [
                  Tab(text: 'Used'),
                  Tab(text: 'Earned'),
                  Tab(text: 'Recharge'),
                ],
              ),
            ),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTransactionList(_usedTransactions, 'USED'),
                  _buildTransactionList(_earnedTransactions, 'EARNED'),
                  _buildTransactionList(_rechargeTransactions, 'RECHARGE'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList(
      List<Map<String, dynamic>> transactions, String type) {
    if (_isLoading && transactions.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF8B5CF6),
        ),
      );
    }

    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getTransactionIcon(type),
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No ${_getTabTitle(_tabController.index).toLowerCase()} transactions yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your ${_getTabTitle(_tabController.index).toLowerCase()} coin history will appear here',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadTransactions(refresh: true),
      color: const Color(0xFF8B5CF6),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: transactions.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == transactions.length) {
            // Load more indicator
            if (_hasMore && !_isLoading) {
              _loadTransactions();
            }
            return _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF8B5CF6),
                      ),
                    ),
                  )
                : const SizedBox.shrink();
          }

          final transaction = transactions[index];
          return _buildTransactionCard(transaction);
        },
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    final type = transaction['type'] as String;
    final amount = transaction['amount'] as int;
    final description =
        transaction['description'] as String? ?? 'No description';
    final createdAt = DateTime.parse(transaction['createdAt'] as String);
    final status = transaction['status'] as String;
    final relatedPost = transaction['relatedPost'] as Map<String, dynamic>?;
    final relatedUser = transaction['relatedUser'] as Map<String, dynamic>?;
    final payment = transaction['payment'] as Map<String, dynamic>?;

    // For USED transactions, always show in red without prefix
    // For RECHARGE and EARNED, show in green with + prefix
    final isUsed = type == 'USED';
    final amountColor = isUsed ? Colors.red : Colors.green;
    final amountPrefix = isUsed ? '' : '+';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getTransactionColor(type).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getTransactionIcon(type),
                  color: _getTransactionColor(type),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (relatedPost != null) ...[
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () => _navigateToPost(relatedPost['id']),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF8B5CF6).withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.article_outlined,
                                    size: 14,
                                    color: const Color(0xFF8B5CF6),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      relatedPost['title']?.isNotEmpty == true
                                          ? relatedPost['title']
                                          : 'Untitled Post',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF8B5CF6),
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 12,
                                    color: const Color(0xFF8B5CF6),
                                  ),
                                ],
                              ),
                              if (relatedPost['user'] != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Builder(
                                      builder: (context) {
                                        final avatarUrl =
                                            relatedPost['user']['avatarUrl'];
                                        print('🔍 Avatar URL: $avatarUrl');

                                        if (avatarUrl != null &&
                                            avatarUrl.toString().isNotEmpty) {
                                          return CircleAvatar(
                                            radius: 8,
                                            backgroundImage: NetworkImage(
                                                avatarUrl.toString()),
                                            onBackgroundImageError:
                                                (exception, stackTrace) {
                                              print(
                                                  '❌ Avatar load error for $avatarUrl: $exception');
                                            },
                                            child: const Icon(
                                              Icons.person,
                                              size: 12,
                                              color: Colors.grey,
                                            ),
                                          );
                                        } else {
                                          return CircleAvatar(
                                            radius: 8,
                                            backgroundColor: Colors.grey[300],
                                            child: const Icon(
                                              Icons.person,
                                              size: 12,
                                              color: Colors.grey,
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'by ${relatedPost['user']['firstName'] != null && relatedPost['user']['lastName'] != null ? '${relatedPost['user']['firstName']} ${relatedPost['user']['lastName']}' : relatedPost['user']['username'] ?? 'Unknown'}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (relatedPost['content'] != null &&
                                  relatedPost['content']
                                      .toString()
                                      .isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  relatedPost['content'].toString(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[700],
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (relatedUser != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Builder(
                              builder: (context) {
                                final avatarUrl = relatedUser['avatarUrl'];
                                print('🔍 Related User Avatar URL: $avatarUrl');

                                if (avatarUrl != null &&
                                    avatarUrl.toString().isNotEmpty) {
                                  return CircleAvatar(
                                    radius: 10,
                                    backgroundImage:
                                        NetworkImage(avatarUrl.toString()),
                                    onBackgroundImageError:
                                        (exception, stackTrace) {
                                      print(
                                          '❌ Related user avatar load error for $avatarUrl: $exception');
                                    },
                                    child: const Icon(
                                      Icons.person,
                                      size: 14,
                                      color: Colors.grey,
                                    ),
                                  );
                                } else {
                                  return CircleAvatar(
                                    radius: 10,
                                    backgroundColor: Colors.grey[300],
                                    child: const Icon(
                                      Icons.person,
                                      size: 14,
                                      color: Colors.grey,
                                    ),
                                  );
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    type == 'EARNED'
                                        ? 'Purchased by:'
                                        : 'Related user:',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    relatedUser['firstName'] != null &&
                                            relatedUser['lastName'] != null
                                        ? '${relatedUser['firstName']} ${relatedUser['lastName']}'
                                        : relatedUser['username'] ?? 'Unknown',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              type == 'EARNED'
                                  ? Icons.shopping_cart
                                  : Icons.person,
                              size: 14,
                              color:
                                  type == 'EARNED' ? Colors.green : Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$amountPrefix${amount.abs()} coins',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: amountColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: status == 'COMPLETED'
                          ? Colors.green.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: status == 'COMPLETED'
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 14,
                color: Colors.grey[500],
              ),
              const SizedBox(width: 4),
              Text(
                _formatDateTime(createdAt),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
              if (payment != null) ...[
                const Spacer(),
                Icon(
                  Icons.payment,
                  size: 14,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 4),
                Text(
                  '\$${payment['amount']} ${payment['currency']}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ],
          ),
          // Show extOrderId for RECHARGE transactions
          if (type == 'RECHARGE' &&
              payment != null &&
              payment['extOrderId'] != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.receipt_long,
                  size: 14,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 4),
                Text(
                  'Order ID: ${payment['extOrderId']}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _navigateToPost(String postId) {
    if (postId.isNotEmpty) {
      context.push('/main/post/$postId');
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  String _formatDateTime(DateTime date) {
    // Format as: "2024-12-25 14:30:45"
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final second = date.second.toString().padLeft(2, '0');

    return '$year-$month-$day $hour:$minute:$second';
  }
}
