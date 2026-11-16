// A chart's `tooltip` map is fl_chart's touch tooltip configuration. Ruby
// sends it as-is (no Flet `_internals.skip_properties`), so the chart must
// keep it out of the generic control tooltip LayoutControl adds.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart' show Tooltip;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet_charts/ruflet_charts.dart';

import 'support/harness.dart';

Map<String, dynamic> chart(String type, Object? tooltip) {
  final props = <String, dynamic>{
    'width': 300,
    'height': 200,
    'tooltip': tooltip,
  };
  return switch (type) {
    'BarChart' => wire(type, 1, {
        ...props,
        'groups': [
          wire('BarChartGroup', 2, {
            'x': 0,
            'rods': [
              wire('BarChartRod', 3, {'to_y': 8}),
            ],
          }),
        ],
      }),
    'LineChart' => wire(type, 1, {
        ...props,
        'data_series': [
          wire('LineChartData', 2, {
            'points': [
              wire('LineChartDataPoint', 3, {'x': 1, 'y': 2}),
            ],
          }),
        ],
      }),
    'ScatterChart' => wire(type, 1, {
        ...props,
        'spots': [
          wire('ScatterChartSpot', 2, {'x': 1, 'y': 2}),
        ],
      }),
    _ => wire(type, 1, {
        ...props,
        'spots': [
          wire('CandlestickChartSpot', 2,
              {'x': 1, 'open': 2, 'high': 4, 'low': 1, 'close': 3}),
        ],
      }),
  };
}

/// The touch tooltip background color the chart hands fl_chart.
Color touchTooltipColor(WidgetTester tester, String type) {
  switch (type) {
    case 'BarChart':
      final data = tester.widget<BarChart>(find.byType(BarChart)).data;
      return data.barTouchData.touchTooltipData
          .getTooltipColor(data.barGroups.single);
    case 'LineChart':
      final data = tester.widget<LineChart>(find.byType(LineChart)).data;
      final bar = data.lineBarsData.single;
      return data.lineTouchData.touchTooltipData
          .getTooltipColor(LineBarSpot(bar, 0, bar.spots.single));
    case 'ScatterChart':
      final data = tester.widget<ScatterChart>(find.byType(ScatterChart)).data;
      return data.scatterTouchData.touchTooltipData
          .getTooltipColor(data.scatterSpots.single);
    default:
      final data =
          tester.widget<CandlestickChart>(find.byType(CandlestickChart)).data;
      return data.candlestickTouchData.touchTooltipData
          .getTooltipColor(data.candlestickSpots.single);
  }
}

void main() {
  const types = ['BarChart', 'LineChart', 'ScatterChart', 'CandlestickChart'];
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final type in types) {
      testWidgets(
          '$type tooltip map configures the touch tooltip only ($platform)',
          (tester) async {
        await mountWire(tester, platform, chart(type, {'bgcolor': '#ff0000'}),
            extensions: [Extension()]);

        expect(tester.takeException(), isNull);
        final rendered = find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == type);
        expect(tester.getSize(rendered), const Size(300, 200));
        expect(touchTooltipColor(tester, type), const Color(0xFFFF0000));
        expect(find.byType(Tooltip), findsNothing);
      });
    }

    testWidgets('a text tooltip stays the control tooltip ($platform)',
        (tester) async {
      await mountWire(tester, platform, chart('BarChart', 'Sales'),
          extensions: [Extension()]);

      expect(tester.takeException(), isNull);
      expect(find.byType(BarChart), findsOneWidget);
      if (platform == TargetPlatform.android) {
        expect(find.byTooltip('Sales'), findsOneWidget);
      }
    });
  }
}
