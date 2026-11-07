import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

import 'courses_screen.dart';
import 'past_papers_screen.dart';
import 'profile_screen.dart';
import 'my_learning_screen.dart';

/// Keeps each tab's state, including the course search and scroll position.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedTab,
        children: [
          const CoursesScreen(),
          MyLearningScreen(
            onBrowseCourses: () => setState(() => _selectedTab = 0),
          ),
          PastPapersScreen(
            active: _selectedTab == 2,
            onBrowseCourses: () => setState(() => _selectedTab = 0),
          ),
          ProfileScreen(
            onBrowseCourses: () => setState(() => _selectedTab = 0),
          ),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border, width: 2)),
        ),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: NavigationBar(
              selectedIndex: _selectedTab,
              onDestinationSelected: (index) =>
                  setState(() => _selectedTab = index),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.menu_book_outlined),
                  selectedIcon: _SelectedIcon(Icons.menu_book_rounded),
                  label: 'Courses',
                ),
                NavigationDestination(
                  icon: Icon(Icons.school_outlined),
                  selectedIcon: _SelectedIcon(Icons.school_rounded),
                  label: 'My Learning',
                ),
                NavigationDestination(
                  icon: Icon(Icons.assignment_outlined),
                  selectedIcon: _SelectedIcon(Icons.assignment_rounded),
                  label: 'Past Papers',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: _SelectedIcon(Icons.person_rounded),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedIcon extends StatelessWidget {
  const _SelectedIcon(this.icon);
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.amberTint,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.amber, width: 2),
      boxShadow: const [
        BoxShadow(color: AppColors.amberDark, offset: Offset(0, 2)),
      ],
    ),
    child: Icon(icon, color: AppColors.navy, size: 25),
  );
}
