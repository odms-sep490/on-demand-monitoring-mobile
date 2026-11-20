import 'package:flutter_test/flutter_test.dart';
import 'package:odms_mobile/features/manager/delivery_page.dart';

void main() {
  test('surplus confirmation hashes the same payload as the web', () {
    expect(
      deliveryPublishFingerprint('order', {
        'baseReviewRoundId': 'round',
        'expectedReviewRoundVersion': 3,
        'notes': ' note ',
        'checklists': [
          {
            'orderChecklistItemId': 'item',
            'addMediaAssetIds': ['b', 'a'],
            'removeRoundEvidenceIds': ['c'],
            'replacements': [
              {'sourceRoundEvidenceId': 'd', 'newMediaAssetId': 'e'},
            ],
          },
        ],
      }),
      '88373e90d04dfc74a4346c28b69d1c71045de7a116063d1bec908ef91159d050',
    );
  });
}
