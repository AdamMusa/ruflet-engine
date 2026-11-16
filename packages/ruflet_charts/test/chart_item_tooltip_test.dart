// Ruby sends a data item's tooltip as the item's own `tooltip` (a text or a
// map of options), never as Flet's `_internals.tooltip`.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet_charts/ruflet_charts.dart';

import 'support/harness.dart';

const customTooltip = {
  'text': 'Max',
  'text_style': {'color': '#00ff00', 'size': 13},
};

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    group('data item tooltips ($platform)', () {
      testWidgets('bar rods show the tooltip Ruby sent', (tester) async {
        await mountWire(
            tester,
            platform,
            wire('BarChart', 1, {
              'width': 300,
              'height': 200,
              'groups': [
                wire('BarChartGroup', 2, {
                  'x': 0,
                  'rods': [
                    wire('BarChartRod', 3, {'to_y': 8, 'tooltip': 'Peak'}),
                    wire('BarChartRod', 4,
                        {'to_y': 6, 'tooltip': customTooltip}),
                    wire('BarChartRod', 5, {'to_y': 4}),
                    wire('BarChartRod', 6, {
                      'to_y': 2,
                      'tooltip': 'Hidden',
                      'show_tooltip': false
                    }),
                  ],
                }),
              ],
            }),
            extensions: [Extension()]);

        final data = tester.widget<BarChart>(find.byType(BarChart)).data;
        final group = data.barGroups.single;
        BarTooltipItem? item(int rod) => data.barTouchData.touchTooltipData
            .getTooltipItem(group, 0, group.barRods[rod], rod);
        expect(item(0)?.text, 'Peak');
        expect(item(1)?.text, 'Max');
        expect(item(1)?.textStyle.color, const Color(0xFF00FF00));
        expect(item(1)?.textStyle.fontSize, 13);
        expect(item(2)?.text, '4.0', reason: 'no tooltip: the rod value');
        expect(item(3), isNull);
      });

      testWidgets('line points show the tooltip Ruby sent', (tester) async {
        await mountWire(
            tester,
            platform,
            wire('LineChart', 1, {
              'width': 300,
              'height': 200,
              'data_series': [
                wire('LineChartData', 2, {
                  'points': [
                    wire('LineChartDataPoint', 3,
                        {'x': 1, 'y': 1, 'tooltip': 'Start'}),
                    wire('LineChartDataPoint', 4,
                        {'x': 2, 'y': 3, 'tooltip': customTooltip}),
                    wire('LineChartDataPoint', 5, {'x': 3, 'y': 2}),
                  ],
                }),
              ],
            }),
            extensions: [Extension()]);

        final data = tester.widget<LineChart>(find.byType(LineChart)).data;
        final bar = data.lineBarsData.single;
        final items = data.lineTouchData.touchTooltipData.getTooltipItems([
          for (var i = 0; i < bar.spots.length; i++)
            LineBarSpot(bar, 0, bar.spots[i]),
        ]);
        expect(items.map((i) => i?.text).toList(), ['Start', 'Max', '2.0']);
        expect(items[1]?.textStyle.color, const Color(0xFF00FF00));
      });

      testWidgets('scatter spots show the tooltip Ruby sent', (tester) async {
        await mountWire(
            tester,
            platform,
            wire('ScatterChart', 1, {
              'width': 300,
              'height': 200,
              'spots': [
                wire(
                    'ScatterChartSpot', 2, {'x': 1, 'y': 2, 'tooltip': 'Here'}),
                wire('ScatterChartSpot', 3, {'x': 2, 'y': 3}),
              ],
            }),
            extensions: [Extension()]);

        final data =
            tester.widget<ScatterChart>(find.byType(ScatterChart)).data;
        final tooltip = data.scatterTouchData.touchTooltipData;
        expect(tooltip.getTooltipItems(data.scatterSpots[0])?.text, 'Here');
        expect(tooltip.getTooltipItems(data.scatterSpots[1])?.text, '3.0');
      });

      testWidgets('candlestick spots show the tooltip Ruby sent',
          (tester) async {
        await mountWire(
            tester,
            platform,
            wire('CandlestickChart', 1, {
              'width': 300,
              'height': 200,
              'spots': [
                wire('CandlestickChartSpot', 2, {
                  'x': 1,
                  'open': 2,
                  'high': 4,
                  'low': 1,
                  'close': 3,
                  'tooltip': customTooltip,
                }),
              ],
            }),
            extensions: [Extension()]);

        final data =
            tester.widget<CandlestickChart>(find.byType(CandlestickChart)).data;
        final item = data.candlestickTouchData.touchTooltipData.getTooltipItems(
            data.candlestickPainter, data.candlestickSpots.single, 0);
        expect(item?.text, 'Max');
        expect(item?.textStyle?.color, const Color(0xFF00FF00));
      });
    });
  }
}
