import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_lingua/shared/layout/nexus_breakpoints.dart';
import 'package:nexus_lingua/shared/layout/study_layout.dart';

void main() {
  testWidgets('typist when width >= 840 and height >= studyCompactMaxHeightLp',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(
              NexusBreakpoints.wideLayoutMinWidthLp,
              600,
            ),
          ),
          child: Builder(
            builder: (context) {
              return Text(
                StudyLayout.useTypistMode(context) ? 'typist' : 'compact',
              );
            },
          ),
        ),
      ),
    );
    expect(find.text('typist'), findsOneWidget);
  });

  testWidgets('compact when wide but short viewport', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(900, 400),
          ),
          child: Builder(
            builder: (context) {
              return Text(
                StudyLayout.useTypistMode(context) ? 'typist' : 'compact',
              );
            },
          ),
        ),
      ),
    );
    expect(find.text('compact'), findsOneWidget);
  });

  testWidgets('compact when narrow width', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 800),
          ),
          child: Builder(
            builder: (context) {
              return Text(
                StudyLayout.useTypistMode(context) ? 'typist' : 'compact',
              );
            },
          ),
        ),
      ),
    );
    expect(find.text('compact'), findsOneWidget);
  });

  testWidgets('compact at height just below floor', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(
              900,
              NexusBreakpoints.studyCompactMaxHeightLp - 1,
            ),
          ),
          child: Builder(
            builder: (context) {
              return Text(
                StudyLayout.useTypistMode(context) ? 'typist' : 'compact',
              );
            },
          ),
        ),
      ),
    );
    expect(find.text('compact'), findsOneWidget);
  });
}
