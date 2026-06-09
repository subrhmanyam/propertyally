import '../../../../core/network/api_client.dart';
import '../../domain/entities/report_data.dart';

class ReportsRepository {
  Future<OccupancyReport> getOccupancy() async {
    final res = await ApiClient.instance.get('/api/v1/reports/data/occupancy');
    return OccupancyReport.fromJson(res.data as Map<String, dynamic>);
  }

  Future<CashFlowReport> getCashFlow({int months = 12}) async {
    final res = await ApiClient.instance.get(
      '/api/v1/reports/data/cash-flow',
      queryParameters: {'months': months},
    );
    return CashFlowReport.fromJson(res.data as Map<String, dynamic>);
  }

  Future<RentCollectionReport> getRentCollection({int? year, int? month}) async {
    final params = <String, dynamic>{};
    if (year != null) params['year'] = year;
    if (month != null) params['month'] = month;
    final res = await ApiClient.instance.get(
      '/api/v1/reports/data/rent-collection',
      queryParameters: params.isEmpty ? null : params,
    );
    return RentCollectionReport.fromJson(res.data as Map<String, dynamic>);
  }

  Future<MaintenanceCostReport> getMaintenanceCosts({int months = 12}) async {
    final res = await ApiClient.instance.get(
      '/api/v1/reports/data/maintenance-costs',
      queryParameters: {'months': months},
    );
    return MaintenanceCostReport.fromJson(res.data as Map<String, dynamic>);
  }

  Future<ProfitLossReport> getProfitLoss({int? year, int months = 12}) async {
    final params = <String, dynamic>{};
    if (year != null) params['year'] = year;
    params['months'] = months;
    final res = await ApiClient.instance.get(
      '/api/v1/reports/data/profit-loss',
      queryParameters: params,
    );
    return ProfitLossReport.fromJson(res.data as Map<String, dynamic>);
  }
}
