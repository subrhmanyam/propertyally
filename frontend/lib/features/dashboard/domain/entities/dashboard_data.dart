import '../../../../shared/widgets/status_badge.dart';

class RecentProperty {
  const RecentProperty({
    required this.name,
    required this.address,
    required this.status,
    this.imageUrl,
  });

  final String name;
  final String address;
  final PropertyStatus status;
  final String? imageUrl;
}

class DashboardTask {
  const DashboardTask({
    required this.title,
    required this.propertyName,
    required this.propertyAddress,
    this.isRecurring = false,
    this.avatarInitial = 'M',
  });

  final String title;
  final String propertyName;
  final String propertyAddress;
  final bool isRecurring;
  final String avatarInitial;
}

class AccountingMonth {
  const AccountingMonth({
    required this.month,
    required this.income,
    required this.expense,
  });

  final String month;
  final double income;
  final double expense;
}

class DashboardData {
  const DashboardData({
    required this.todayDate,
    required this.reminderCount,
    required this.onboardingProgress,
    required this.onboardingStep,
    required this.onboardingTotal,
    required this.recentProperties,
    required this.tasks,
    required this.accountingMonths,
    required this.totalIncome,
    required this.totalExpenses,
  });

  final String todayDate;
  final int reminderCount;
  final double onboardingProgress;
  final int onboardingStep;
  final int onboardingTotal;
  final List<RecentProperty> recentProperties;
  final List<DashboardTask> tasks;
  final List<AccountingMonth> accountingMonths;
  final double totalIncome;
  final double totalExpenses;

  static const DashboardData mock = DashboardData(
    todayDate: 'Today, Apr 15',
    reminderCount: 1,
    onboardingProgress: 0.75,
    onboardingStep: 7,
    onboardingTotal: 8,
    totalIncome: 16920.00,
    totalExpenses: 4884.93,
    recentProperties: [
      RecentProperty(
        name: 'Orange County, OR',
        address: '356 Boardman Ave NE, Boardman, OR, 97...',
        status: PropertyStatus.occupied,
      ),
      RecentProperty(
        name: 'Boardman Main House, Unit A',
        address: '123 3rd St NE, Boardman, OR, 97818, US',
        status: PropertyStatus.vacant,
      ),
      RecentProperty(
        name: 'Luxury apartments, Unit 2',
        address: '377 NW 10th St, Hermiston, OR, 97838, US',
        status: PropertyStatus.occupied,
      ),
      RecentProperty(
        name: 'Luxury apartments, Unit 3',
        address: '377 NW 10th St, Hermiston, OR, 97838, US',
        status: PropertyStatus.occupied,
      ),
      RecentProperty(
        name: 'Villa de luxe',
        address: '1808 Main St, Victoria, VA, 23974, US',
        status: PropertyStatus.occupied,
      ),
      RecentProperty(
        name: 'New property, Unit A',
        address: '1231 116th Ave NE, Bellevue, WA, 98004, US',
        status: PropertyStatus.occupied,
      ),
      RecentProperty(
        name: 'Nightingale house',
        address: '123 Willow Fork Dr SW, Boardman, OR, 97...',
        status: PropertyStatus.occupied,
      ),
      RecentProperty(
        name: 'Luxury apartments, Unit 1100',
        address: '377 NW 10th St, Hermiston, OR, 97838, US',
        status: PropertyStatus.occupied,
      ),
      RecentProperty(
        name: 'Precious House',
        address: '12333 NE 130th Ln, Kirkland, WA, 98034,...',
        status: PropertyStatus.occupied,
      ),
    ],
    tasks: [
      DashboardTask(
        title: 'Change filters',
        propertyName: 'Orange C...',
        propertyAddress: '356 Boardm...',
        isRecurring: true,
      ),
      DashboardTask(
        title: 'Insurance',
        propertyName: '123 Willow...',
        propertyAddress: '123 Willow F...',
        isRecurring: true,
      ),
      DashboardTask(
        title: 'Insurance',
        propertyName: '123 Willow...',
        propertyAddress: '123 Willow F...',
        isRecurring: true,
      ),
      DashboardTask(
        title: 'Send bills to tenants',
        propertyName: 'Villa de luxe',
        propertyAddress: '1808 Main St...',
        isRecurring: false,
      ),
    ],
    accountingMonths: [
      AccountingMonth(month: 'Aug', income: 1200, expense: 400),
      AccountingMonth(month: 'Sep', income: 2100, expense: 800),
      AccountingMonth(month: 'Oct', income: 900,  expense: 300),
      AccountingMonth(month: 'Nov', income: 3200, expense: 1100),
      AccountingMonth(month: 'Dec', income: 4800, expense: 1500),
      AccountingMonth(month: 'Jan', income: 5200, expense: 1800),
      AccountingMonth(month: 'Feb', income: 5000, expense: 1600),
      AccountingMonth(month: 'Mar', income: 4500, expense: 1400),
      AccountingMonth(month: 'Apr', income: 4200, expense: 1300),
    ],
  );
}
