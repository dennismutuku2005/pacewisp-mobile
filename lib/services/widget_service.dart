import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class WidgetService {
  static const String _groupId = 'group.com.pacewisp.pacewisp'; // For iOS if needed later
  static const String _androidWidgetName = 'AppWidgetProvider';
  static const String _androidClassName = 'AppWidgetProvider';

  static Future<void> updateWidgetData({
    required String accountName,
    required dynamic income,
    required dynamic entries,
    bool isBlurred = true,
  }) async {
    final currencyFormat = NumberFormat("#,###", "en_US");
    
    String formattedIncome = "0";
    try {
      final double n = double.parse(income.toString());
      formattedIncome = "KSH ${currencyFormat.format(n.toInt())}";
    } catch (e) {
      formattedIncome = income.toString();
    }

    await HomeWidget.saveWidgetData<String>('account_name', accountName);
    await HomeWidget.saveWidgetData<String>('income', formattedIncome);
    await HomeWidget.saveWidgetData<String>('entries', entries.toString());
    await HomeWidget.saveWidgetData<bool>('is_blurred', isBlurred);
    
    await HomeWidget.updateWidget(
      name: _androidWidgetName,
      androidName: _androidClassName,
    );
  }

  static Future<void> toggleBlur() async {
    final bool? currentBlur = await HomeWidget.getWidgetData<bool>('is_blurred', defaultValue: true);
    await HomeWidget.saveWidgetData<bool>('is_blurred', !(currentBlur ?? true));
    await HomeWidget.updateWidget(
      name: _androidWidgetName,
      androidName: _androidClassName,
    );
  }

  @pragma('vm:entry-point')
  static Future<void> backgroundCallback(Uri? uri) async {
    if (uri?.host == 'sync_data') {
      await refreshDataFromApi();
    }
  }

  static Future<void> refreshDataFromApi() async {
    try {
      final api = ApiService();
      await api.init();
      
      final res = await api.getSummaryWidgets(forceRefresh: true);
      if (res != null) {
        final data = res['data'] ?? res['widgets'] ?? res;
        final String income = (data['todays_earnings']?['value'] ?? "0").toString();
        final String entries = (data['active_users']?['value'] ?? "0").toString();
        
        final prefs = await SharedPreferences.getInstance();
        final String accountName = prefs.getString('account_name') ?? "PaceWisp Admin";
        final bool isBlurred = prefs.getBool('is_widget_blurred') ?? true;

        await updateWidgetData(
          accountName: accountName,
          income: income,
          entries: entries,
          isBlurred: isBlurred,
        );
      }
    } catch (e) {
      print("Widget Background Sync Error: $e");
    }
  }
}
