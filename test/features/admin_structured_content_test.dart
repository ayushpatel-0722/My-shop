import 'package:flutter/material.dart';
import 'package:myshop/app/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myshop/core/models/product.dart';
import 'package:myshop/features/admin/products/widgets/structured_content_editors.dart';

/// A1 — structured Highlights + All Details editors.
///
/// Highlights = N {title,value} rows; All Details = N sections typed
/// "text" or "keyValue". Both support add / delete / reorder, type changes
/// ask for confirmation and validation blocks incomplete content.
void main() {
  Widget shell(Widget child) => MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,

    theme: ThemeData.light(),
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: child,
      ),
    ),
  );

  group('HighlightsEditor', () {
    testWidgets('starts with an empty state and adds rows', (tester) async {
      var rows = <HighlightItem>[];
      await tester.pumpWidget(
        shell(
          StatefulBuilder(
            builder: (context, setState) => HighlightsEditor(
              value: rows,
              onChanged: (r) => setState(() => rows = r),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('highlights-empty')), findsOneWidget);
      expect(find.text('No highlights yet — tap "Add Highlight".'), findsOneWidget);

      await tester.tap(find.byKey(const Key('add-highlight')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('highlights-empty')), findsNothing);
      expect(find.byKey(const Key('highlight-row-0')), findsOneWidget);
      expect(rows.length, 1);
    });

    testWidgets('rows edit title and value and report changes', (tester) async {
      var rows = const [HighlightItem(title: 'RAM', value: '8 GB')];
      await tester.pumpWidget(
        shell(
          StatefulBuilder(
            builder: (context, setState) => HighlightsEditor(
              value: rows,
              onChanged: (r) => setState(() => rows = r),
            ),
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('highlight-title-0')),
        'Storage',
      );
      await tester.pumpAndSettle();
      expect(rows.single.title, 'Storage');

      await tester.enterText(
        find.byKey(const Key('highlight-value-0')),
        '128 GB',
      );
      await tester.pumpAndSettle();
      expect(rows.single.value, '128 GB');
    });

    testWidgets('reorder and delete wire through the callbacks', (
      tester,
    ) async {
      var rows = const [
        HighlightItem(title: 'First', value: '1'),
        HighlightItem(title: 'Second', value: '2'),
      ];
      await tester.pumpWidget(
        shell(
          StatefulBuilder(
            builder: (context, setState) => HighlightsEditor(
              value: rows,
              onChanged: (r) => setState(() => rows = r),
            ),
          ),
        ),
      );

      // Move "Second" above "First".
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('highlight-row-1')),
          matching: find.byTooltip('Move up'),
        ),
      );
      await tester.pumpAndSettle();
      expect(rows.map((r) => r.title), ['Second', 'First']);

      // Delete the new first row.
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('highlight-row-0')),
          matching: find.byTooltip('Delete row'),
        ),
      );
      await tester.pumpAndSettle();
      expect(rows.map((r) => r.title), ['First']);
    });

    testWidgets('showErrors flags a half-written row', (tester) async {
      final rows = [const HighlightItem(title: 'Net', value: '')];
      await tester.pumpWidget(
        shell(
          StatefulBuilder(
            builder: (context, setState) => HighlightsEditor(
              value: rows,
              showErrors: true,
              onChanged: (r) => setState(() {}),
            ),
          ),
        ),
      );

      expect(find.text('Required'), findsOneWidget);
    });

    test('isValid accepts migrated value-only rows', () {
      expect(
        HighlightsEditor.isValid(const [
          HighlightItem(title: '', value: '500g glass jar'),
        ]),
        isTrue,
      );
      expect(
        HighlightsEditor.isValid(const [
          HighlightItem(title: 'Net', value: ''),
        ]),
        isFalse,
        reason: 'a started row must be finished',
      );
    });
  });

  group('AllDetailsEditor', () {
    testWidgets('adds sections and starts them expanded for editing', (
      tester,
    ) async {
      var sections = <DetailSection>[];
      await tester.pumpWidget(
        shell(
          StatefulBuilder(
            builder: (context, setState) => AllDetailsEditor(
              value: sections,
              onChanged: (s) => setState(() => sections = s),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('details-empty')), findsOneWidget);

      await tester.tap(find.byKey(const Key('add-detail-section')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('detail-section-0')), findsOneWidget);
      expect(find.byKey(const Key('detail-section-title-0')), findsOneWidget);
      expect(sections.length, 1);
    });

    testWidgets('text sections edit their paragraph', (tester) async {
      var sections = const [
        DetailSection(
          title: 'Description',
          type: DetailSectionType.text,
          text: 'Old text',
        ),
      ];
      await tester.pumpWidget(
        shell(
          StatefulBuilder(
            builder: (context, setState) => AllDetailsEditor(
              value: sections,
              onChanged: (s) => setState(() => sections = s),
            ),
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('detail-section-text-0')),
        'Fresh paragraph',
      );
      await tester.pumpAndSettle();
      expect(sections.single.text, 'Fresh paragraph');
    });

    testWidgets('keyValue sections add and edit their rows', (tester) async {
      var sections = const [
        DetailSection(
          title: 'Specs',
          type: DetailSectionType.keyValue,
          items: [DetailItem(title: 'Shelf Life', value: '6 Months')],
        ),
      ];
      await tester.pumpWidget(
        shell(
          StatefulBuilder(
            builder: (context, setState) => AllDetailsEditor(
              value: sections,
              onChanged: (s) => setState(() => sections = s),
            ),
          ),
        ),
      );

      // Existing row renders and one more can be added.
      expect(find.byKey(const Key('key-value-row-0')), findsOneWidget);
      await tester.tap(find.byKey(const Key('add-detail-item-0')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('key-value-row-1')), findsOneWidget);
      expect(sections.single.items.length, 2);

      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('key-value-row-1')),
          matching: find.byType(TextFormField).at(0),
        ),
        'Storage',
      );
      await tester.pumpAndSettle();
      expect(sections.single.items[1].title, 'Storage');
    });

    testWidgets('changing the type on filled content asks for confirmation', (
      tester,
    ) async {
      var sections = const [
        DetailSection(
          title: 'Description',
          type: DetailSectionType.text,
          text: 'Keep me',
        ),
      ];
      await tester.pumpWidget(
        shell(
          StatefulBuilder(
            builder: (context, setState) => AllDetailsEditor(
              value: sections,
              onChanged: (s) => setState(() => sections = s),
            ),
          ),
        ),
      );

      // Sections start expanded, so the type dropdown is already visible.
      final typeDropdown = find.byType(DropdownButtonFormField<String>);
      expect(typeDropdown, findsOneWidget);

      await tester.tap(typeDropdown);
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(DropdownMenuItem<String>, 'Title & Value'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Change Section Type'), findsOneWidget);
      expect(
        find.text('Switching the type will clear the content of this section. Continue?'),
        findsOneWidget,
      );

      // Cancel keeps the section untouched.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(sections.single.type, DetailSectionType.text);
      expect(sections.single.text, 'Keep me');

      // Confirming clears the old content and switches the type.
      await tester.tap(typeDropdown);
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(DropdownMenuItem<String>, 'Title & Value'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change & Clear'));
      await tester.pumpAndSettle();

      expect(sections.single.type, DetailSectionType.keyValue);
      expect(sections.single.text, isEmpty);
    });

    testWidgets('deleting a section asks for confirmation', (tester) async {
      var sections = const [
        DetailSection(title: 'Warranty', type: DetailSectionType.text, text: '1 year'),
      ];
      await tester.pumpWidget(
        shell(
          StatefulBuilder(
            builder: (context, setState) => AllDetailsEditor(
              value: sections,
              onChanged: (s) => setState(() => sections = s),
            ),
          ),
        ),
      );

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('detail-section-0')),
          matching: find.byTooltip('Delete section'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Delete Section'), findsOneWidget);
      expect(find.textContaining('Warranty'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(sections, isEmpty);
    });

    test('isValid enforces the per-type rules', () {
      expect(
        AllDetailsEditor.isValid(const [
          DetailSection(title: 'Description', type: DetailSectionType.text, text: 'ok'),
        ]),
        isTrue,
      );
      expect(
        AllDetailsEditor.isValid(const [
          DetailSection(title: '', type: DetailSectionType.text, text: 'ok'),
        ]),
        isFalse,
        reason: 'sections need a title',
      );
      expect(
        AllDetailsEditor.isValid(const [
          DetailSection(title: 'Description', type: DetailSectionType.text, text: ''),
        ]),
        isFalse,
        reason: 'text sections need text',
      );
      expect(
        AllDetailsEditor.isValid(const [
          DetailSection(title: 'Specs', type: DetailSectionType.keyValue),
        ]),
        isFalse,
        reason: 'keyValue sections need at least one row',
      );
      expect(
        AllDetailsEditor.isValid(const [
          DetailSection(
            title: 'Specs',
            type: DetailSectionType.keyValue,
            items: [DetailItem(title: 'Key', value: '')],
          ),
        ]),
        isFalse,
        reason: 'keyValue rows need both fields',
      );
    });
  });
}
