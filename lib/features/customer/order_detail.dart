import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../shared/portal_scaffold.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';
import '../manager/order_workspace.dart';
import 'customer_order_workspace.dart';

class OrderDetailPage extends ConsumerWidget {
  const OrderDetailPage({super.key, required this.id, required this.manager});
  final String id;
  final bool manager;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider), path = '/api/orders/${segment(id)}';
    return PortalScaffold(
      appBar: AppBar(
        title: Text(context.tr('Order details', 'Chi tiết đơn hàng')),
      ),
      body: RemoteView(
        load: () => api.request(path),
        builder: (context, value, reload) {
          final order = object(value);

          if (manager) {
            return ManagerOrderWorkspace(id: id, order: order, reload: reload);
          }
          return CustomerOrderWorkspace(
            key: ValueKey(id),
            order: order,
            id: id,
            reload: reload,
          );
        },
      ),
    );
  }
}
