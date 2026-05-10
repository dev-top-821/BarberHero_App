import 'package:flutter/material.dart';

import '../chat/chat_rooms_screen.dart';
import '../dashboard_screen.dart';
import '../wallet_screen.dart';
import 'profile_tab.dart';

/// Bottom-tab shell for the barber app. Mirrors the customer app's
/// `HomeShell` UX: persistent state per tab via [IndexedStack], same
/// navigation pattern + identical tab-bar styling.
///
/// Tab layout:
///   0 — Jobs   (DashboardScreen, the bookings inbox)
///   1 — Wallet (WalletScreen, balance + transactions)
///   2 — Chat   (ChatRoomsScreen)
///   3 — Profile (edit profile, hours, reviews, logout — see ProfileTab)
class HomeShell extends StatefulWidget {
  /// Which bottom-nav tab to show initially.
  final int initialIndex;

  const HomeShell({super.key, this.initialIndex = 0});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _currentIndex = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          DashboardScreen(),
          WalletScreen(),
          ChatRoomsScreen(),
          ProfileTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.work_outline_rounded),
            activeIcon: Icon(Icons.work_rounded),
            label: 'Jobs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Wallet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            activeIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
