import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

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
}
