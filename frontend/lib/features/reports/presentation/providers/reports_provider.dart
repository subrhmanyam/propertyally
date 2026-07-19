import '../../../../core/base/base_provider.dart';
import '../../data/repositories/reports_repository.dart';
import '../../domain/entities/report_data.dart';

enum ReportTab {
  occupancy,
  cashFlow,
  rentCollection,
  maintenanceCosts,
  profitLoss
}

class ReportsProvider extends BaseProvider {
  ReportsProvider() : _repo = ReportsRepository();

  final ReportsRepository _repo;

  ReportTab _activeTab = ReportTab.occupancy;
  ReportTab get activeTab => _activeTab;

  OccupancyReport? occupancy;
  CashFlowReport? cashFlow;
  RentCollectionReport? rentCollection;
  MaintenanceCostReport? maintenanceCosts;
  ProfitLossReport? profitLoss;

  void selectTab(ReportTab tab) {
    _activeTab = tab;
    notifyListeners();
    _loadTab(tab);
  }

  Future<void> loadAll() async {
    await _loadTab(_activeTab);
  }

  Future<void> _loadTab(ReportTab tab) async {
    switch (tab) {
      case ReportTab.occupancy:
        if (occupancy != null) return;
        await runAsync(() async {
          occupancy = await _repo.getOccupancy();
          return occupancy;
        });
      case ReportTab.cashFlow:
        if (cashFlow != null) return;
        await runAsync(() async {
          cashFlow = await _repo.getCashFlow();
          return cashFlow;
        });
      case ReportTab.rentCollection:
        if (rentCollection != null) return;
        await runAsync(() async {
          rentCollection = await _repo.getRentCollection();
          return rentCollection;
        });
      case ReportTab.maintenanceCosts:
        if (maintenanceCosts != null) return;
        await runAsync(() async {
          maintenanceCosts = await _repo.getMaintenanceCosts();
          return maintenanceCosts;
        });
      case ReportTab.profitLoss:
        if (profitLoss != null) return;
        await runAsync(() async {
          profitLoss = await _repo.getProfitLoss();
          return profitLoss;
        });
    }
  }

  Future<void> refresh() async {
    occupancy = null;
    cashFlow = null;
    rentCollection = null;
    maintenanceCosts = null;
    profitLoss = null;
    await _loadTab(_activeTab);
  }
}
