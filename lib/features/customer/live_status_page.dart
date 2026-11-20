import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';

/// Matches the website's in-progress-order hub; the backend has no video stream API.
class LiveStatusPage extends ConsumerStatefulWidget {
  const LiveStatusPage({super.key});
  @override
  ConsumerState<LiveStatusPage> createState() => _LiveStatusPageState();
}

class _LiveStatusPageState extends ConsumerState<LiveStatusPage>
    with WidgetsBindingObserver {
  Timer? timer;
  int version = 0;
  bool visible = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (visible && mounted) setState(() => version++);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    visible = state == AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.tr('Monitoring status', 'Tình trạng giám sát')),
    ),
    body: RemoteView(
      key: ValueKey(version),
      load: () => ref
          .read(apiProvider)
          .request('/api/orders/mine', query: {'status': 'IN_PROGRESS'}),
      builder: (context, data, reload) => RecordList(
        items: records(data),
        refresh: reload,
        onTap: (item) =>
            context.push('/customer/orders/${segment('${item['id']}')}'),
      ),
    ),
  );
}
