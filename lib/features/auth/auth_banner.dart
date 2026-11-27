import 'package:material_ui/material_ui.dart';

import '../../shared/strings.dart';

class AuthBanner extends StatelessWidget {
  const AuthBanner({super.key});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(22),
    child: Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/construction-640.webp'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xF50B2549), Color(0xAD17558B)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 36,
                  height: 36,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'ODMS',
              style: Theme.of(context).textTheme.headlineLarge
                  ?.copyWith(color: Colors.white),
            ),
            Text(
              context.tr('On-demand monitoring', 'Giám sát theo yêu cầu'),
              style: const TextStyle(color: Color(0xFFD9ECFF)),
            ),
          ],
        ),
      ),
    ),
  );
}
