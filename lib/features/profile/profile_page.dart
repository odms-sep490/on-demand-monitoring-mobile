import '../../shared/portal_scaffold.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../shared/editor.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';
import '../auth/session.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    return PortalScaffold(
      appBar: AppBar(title: Text(context.tr('Profile', 'Hồ sơ'))),
      body: RemoteView(
        load: () => api.request('/api/users/me'),
        builder: (context, value, reload) {
          final profile = object(value);
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF102D57), Color(0xFF176481)],
                  ),
                ),
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 24,
                      child: Icon(Icons.person_outline),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${profile['fullName'] ?? ref.watch(sessionProvider).user?.fullName ?? ''}',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(color: Colors.white),
                          ),
                          if (profile['email'] != null)
                            Text(
                              '${profile['email']}',
                              style: const TextStyle(color: Color(0xFFE0F3FF)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                context.tr('Contact information', 'Thông tin liên hệ'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Divider(),
              DetailFields(
                data: profile,
                fields: const {'phoneNumber': ('Phone', 'Điện thoại')},
              ),
              DetailFields(
                data: object(profile['customerProfile']),
                fields: const {
                  'address': ('Address', 'Địa chỉ'),
                  'companyName': ('Company', 'Công ty'),
                  'companyTaxCode': ('Tax code', 'Mã số thuế'),
                },
              ),
              FilledButton.icon(
                icon: const Icon(Icons.edit_outlined),
                label: Text(context.tr('Edit profile', 'Chỉnh sửa hồ sơ')),
                onPressed: () async {
                  final customer =
                      ref.read(sessionProvider).user!.role == AppRole.customer;
                  final body = await editRecord(
                    context,
                    title: context.tr('Edit profile', 'Chỉnh sửa hồ sơ'),
                    initial: {
                      ...profile,
                      ...object(profile['customerProfile']),
                    },
                    fields: [
                      const FieldSpec('fullName', 'Full name', 'Họ và tên'),
                      const FieldSpec(
                        'phoneNumber',
                        'Phone',
                        'Điện thoại',
                        required: false,
                      ),
                      if (customer) ...[
                        const FieldSpec(
                          'address',
                          'Address',
                          'Địa chỉ',
                          required: false,
                        ),
                        const FieldSpec(
                          'companyName',
                          'Company',
                          'Công ty',
                          required: false,
                        ),
                        const FieldSpec(
                          'citizenIdentificationNumber',
                          'Identification number',
                          'Số định danh',
                          required: false,
                        ),
                        const FieldSpec(
                          'companyTaxCode',
                          'Tax code',
                          'Mã số thuế',
                          required: false,
                        ),
                      ],
                    ],
                  );
                  if (body != null &&
                      context.mounted &&
                      await runAction(
                        context,
                        () => api.request(
                          '/api/users/me',
                          method: 'PATCH',
                          body: body,
                        ),
                      )) {
                    reload();
                  }
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () async {
                  await runAction(context, ref.read(sessionProvider).logout);
                },
                child: Text(context.tr('Sign out', 'Đăng xuất')),
              ),
            ],
          );
        },
      ),
    );
  }
}
