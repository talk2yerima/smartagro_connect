import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagro_connect/core/constants/app_colors.dart';
import 'package:smartagro_connect/shared/widgets/farmland_illustration.dart';

void main() {
  testWidgets('the sign-in landscape paints on the green header',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(392, 300));
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.gradientGreen),
          child: SizedBox(
            width: 392,
            height: 300,
            child: FarmlandIllustration(),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(FarmlandIllustration), findsOneWidget);
  });
}
