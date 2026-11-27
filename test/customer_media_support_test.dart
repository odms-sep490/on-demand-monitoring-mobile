import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odms_mobile/features/customer/change_analysis_page.dart';
import 'package:odms_mobile/features/customer/media_page.dart';
import 'package:odms_mobile/features/support/faq_page.dart';

import 'api_client_test.dart' show response;
import 'support/workflow_harness.dart';

const analysisPath = '/api/customer/ai/change-analyses';
const media = [
  {
    'mediaId': 'before',
    'mediaType': 'IMAGE',
    'fileName': 'Roof before.jpg',
    'canDownloadOriginal': true,
    'missionCode': 'MSN-101',
  },
  {
    'mediaId': 'after',
    'mediaType': 'IMAGE',
    'fileName': 'Roof after.jpg',
    'canDownloadOriginal': true,
    'missionCode': 'MSN-101',
  },
  {
    'mediaId': 'locked',
    'mediaType': 'IMAGE',
    'fileName': 'Locked photo.jpg',
    'canDownloadOriginal': false,
  },
  {
    'mediaId': 'video',
    'mediaType': 'VIDEO',
    'fileName': 'Survey.mp4',
    'canDownloadOriginal': true,
    'missionCode': 'MSN-202',
  },
];

void main() {
  testWidgets('library filters photos and videos by type and mission', (
    tester,
  ) async {
    final backend = WorkflowBackend((request) {
      expect(request.path, '/api/customer/available-media');
      return response(media);
    });
    await showWorkflow(tester, backend, const CustomerMediaPage());
    expect(find.text('Roof before.jpg'), findsOneWidget);
    expect(find.text('Survey.mp4'), findsOneWidget);

    await press(tester, find.text('Video'));
    expect(find.text('Survey.mp4'), findsOneWidget);
    expect(find.text('Roof before.jpg'), findsNothing);
    await tester.enterText(find.byType(TextField), '  mSn-101 ');
    await tester.pumpAndSettle();
    expect(find.text('No matching media.'), findsOneWidget);

    await press(tester, find.text('Photos'));
    expect(find.text('Roof before.jpg'), findsOneWidget);
    expect(find.text('Roof after.jpg'), findsOneWidget);
    expect(find.text('Locked photo.jpg'), findsNothing);
    expect(backend.requests, hasLength(1));
  });

  testWidgets('AI requires two eligible photos and opens job history', (
    tester,
  ) async {
    final backend = WorkflowBackend(
      (request) => switch (request.path) {
        analysisPath => response([
          {'id': 'job-1', 'status': 'FAILED'},
          {'id': 'job-2', 'status': 'PROCESSING'},
        ]),
        '$analysisPath/job-1' => response({
          'status': 'FAILED',
          'error_code': 'IMAGE_MISMATCH',
        }),
        _ => throw StateError('Unexpected request: ${request.path}'),
      },
    );
    await showWorkflow(
      tester,
      backend,
      ChangeAnalysisPage(assets: [media[0], media[2], media[3]]),
    );
    expect(
      find.text('Two eligible delivered photos are required.'),
      findsOneWidget,
    );
    final button = find.widgetWithText(FilledButton, 'Choose two photos');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(find.text('Analyzing'), findsOneWidget);

    await press(tester, find.text('Failed'));
    expect(find.text('Comparison results'), findsOneWidget);
    expect(find.text('IMAGE_MISMATCH'), findsOneWidget);
    expect(backend.requests.map((request) => request.path), [
      analysisPath,
      '$analysisPath/job-1',
    ]);
  });

  testWidgets(
    'AI refreshes a pending job and fetches results only after completion',
    (tester) async {
      var detailReads = 0;
      final backend = WorkflowBackend(
        (request) => switch (request.path) {
          analysisPath => response([
            {'id': 'job-1', 'status': 'PENDING'},
          ]),
          '$analysisPath/job-1' => response({
            'status': ++detailReads == 1 ? 'PENDING' : 'COMPLETED',
          }),
          '$analysisPath/job-1/result' => response({
            'changedPixelRatio': .125,
            'overlay': 'invalid base64!',
          }),
          _ => throw StateError('Unexpected request: ${request.path}'),
        },
      );
      await showWorkflow(
        tester,
        backend,
        const ChangeAnalysisPage(assets: media),
      );
      await press(tester, find.text('Queued'));
      expect(backend.requests.map((r) => r.path), [
        analysisPath,
        '$analysisPath/job-1',
      ]);
      await press(tester, find.text('Refresh status'));
      expect(find.text('Complete'), findsOneWidget);
      expect(find.text('Changed area: 12.5%'), findsOneWidget);
      expect(find.text('Detected changes'), findsNothing);
      expect(backend.requests.last.path, '$analysisPath/job-1/result');
    },
  );

  testWidgets(
    'AI rejects duplicate photos and retries the same pair after 503',
    (tester) async {
      final submissions = <Map<String, String>>[];
      final backend = WorkflowBackend((request) {
        expect(request.path, analysisPath);
        if (request.method == 'GET') {
          return response(
            submissions.length == 2
                ? [
                    {'id': 'new-job', 'status': 'PENDING'},
                  ]
                : [],
          );
        }
        submissions.add(Map.fromEntries((request.data as FormData).fields));
        return submissions.length == 1
            ? response(null, status: 503)
            : response({'id': 'new-job'}, status: 201);
      });
      await showWorkflow(
        tester,
        backend,
        const ChangeAnalysisPage(assets: media),
      );
      await press(tester, find.text('Choose two photos'));
      await choose(tester, 'Before', 'Roof before.jpg');
      await choose(tester, 'After', 'Roof before.jpg');
      await press(tester, find.text('Continue'));
      expect(find.text('Choose two different photos.'), findsOneWidget);
      expect(submissions, isEmpty);

      await choose(tester, 'After', 'Roof after.jpg');
      await press(tester, find.text('Continue'));
      expect(
        find.text('The image analysis service is not ready. Try again later.'),
        findsOneWidget,
      );
      expect(submissions.single['beforeAsset'], 'before');
      expect(submissions.single['afterAsset'], 'after');
      expect(submissions.single['requestKey'], isNotEmpty);

      await press(tester, find.text('Choose two photos'));
      await press(tester, find.text('Continue'));
      expect(submissions, hasLength(2));
      expect(submissions.last, submissions.first);
      expect(find.text('Queued'), findsOneWidget);
    },
  );

  testWidgets('FAQ filters articles and retries a rejected feedback vote', (
    tester,
  ) async {
    var attempts = 0;
    final backend = WorkflowBackend((request) {
      if (request.method == 'GET') {
        expect(request.path, '/api/support-tickets/faq-articles');
        return response([
          {
            'articleId': '1',
            'question': 'How do I book?',
            'answer': 'Choose a service.',
            'category': 'BOOKING',
            'categoryLabel': 'Booking',
          },
          {
            'articleId': '2',
            'question': 'Where is my receipt?',
            'answer': 'Open payments.',
            'category': 'FINANCE',
            'categoryLabel': 'Finance',
          },
        ]);
      }
      expect(request.path, '/api/support-tickets/faq-feedback');
      expect(request.data, {
        'articleId': '2',
        'articleQuestion': 'Where is my receipt?',
        'articleCategory': 'FINANCE',
        'isHelpful': false,
      });
      return ++attempts == 1 ? response(null, status: 422) : response(null);
    });
    await showWorkflow(tester, backend, const FaqPage());
    await press(tester, find.text('Finance'));
    expect(find.text('How do I book?'), findsNothing);
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pumpAndSettle();
    expect(find.text('No matching questions.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '  PAYMENTS ');
    await tester.pumpAndSettle();
    await press(tester, find.text('Where is my receipt?'));
    expect(find.text('Open payments.'), findsOneWidget);
    await press(tester, find.text('Not helpful'));
    expect(find.text('Thanks for your feedback.'), findsNothing);
    await press(tester, find.text('Not helpful'));
    expect(find.text('Thanks for your feedback.'), findsOneWidget);
    expect(find.text('Not helpful'), findsNothing);
    expect(attempts, 2);
  });
}
