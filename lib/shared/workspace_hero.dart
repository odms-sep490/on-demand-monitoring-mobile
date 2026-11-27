import 'package:material_ui/material_ui.dart';

class WorkspaceHero extends StatelessWidget {
  const WorkspaceHero({
    super.key,
    required this.title,
    required this.description,
    required this.action,
    this.eyebrow,
    this.image,
  });

  final String title, description;
  final String? eyebrow, image;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        image: image == null
            ? null
            : DecorationImage(image: AssetImage(image!), fit: BoxFit.cover),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: image == null
                ? const [Color(0xFF142855), Color(0xFF493F91)]
                : const [Color(0xF50B2446), Color(0x99133462)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (eyebrow != null)
              Text(
                eyebrow!,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: const Color(0xFFD8E9FF),
                ),
              ),
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(description, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 14),
            action,
          ],
        ),
      ),
    );
  }
}
