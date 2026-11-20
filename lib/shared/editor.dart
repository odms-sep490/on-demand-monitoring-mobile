import 'package:material_ui/material_ui.dart';

import '../core/models.dart';
import 'strings.dart';

enum FieldKind {
  text,
  multiline,
  email,
  number,
  date,
  instant,
  choice,
  multiChoice,
  toggle,
}

class FieldSpec {
  const FieldSpec(
    this.key,
    this.en,
    this.vi, {
    this.kind = FieldKind.text,
    this.required = true,
    this.options = const {},
    this.loadOptions,
    this.min,
    this.max,
    this.initial,
  });
  final String key, en, vi;
  final FieldKind kind;
  final bool required;
  final Map<String, String> options;
  final Future<Map<String, String>> Function()? loadOptions;
  final num? min, max;
  final Object? initial;
}

Future<Json?> editRecord(
  BuildContext context, {
  required String title,
  required List<FieldSpec> fields,
  Json initial = const {},
  String? Function(Json)? validate,
}) => Navigator.of(context).push<Json>(
  MaterialPageRoute(
    builder: (_) => EditorPage(
      title: title,
      fields: fields,
      initial: initial,
      validate: validate,
    ),
  ),
);

class EditorPage extends StatefulWidget {
  const EditorPage({
    super.key,
    required this.title,
    required this.fields,
    this.initial = const {},
    this.validate,
  });
  final String title;
  final List<FieldSpec> fields;
  final Json initial;
  final String? Function(Json)? validate;
  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final form = GlobalKey<FormState>();
  final Json values = {};
  final Map<String, TextEditingController> controllers = {};
  final Map<String, Map<String, String>> options = {};
  bool loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    for (final field in widget.fields) {
      values[field.key] = widget.initial[field.key] ?? field.initial;
      controllers[field.key] = TextEditingController(
        text: '${values[field.key] ?? ''}',
      );
      options[field.key] = field.options;
    }
    load();
  }

  Future<void> load() async {
    try {
      for (final field in widget.fields) {
        if (field.loadOptions != null) {
          options[field.key] = await field.loadOptions!();
        }
      }
      if (mounted) {
        setState(() {
          loading = false;
          error = null;
        });
      }
    } catch (failure) {
      if (mounted) {
        setState(() {
          loading = false;
          error = '$failure';
        });
      }
    }
  }

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> pickDate(FieldSpec field) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse('${values[field.key]}') ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 10),
    );
    if (date == null || !mounted) return;
    String result =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    if (field.kind == FieldKind.instant) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(now),
      );
      if (time == null || !mounted) return;
      result = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ).toUtc().toIso8601String();
    }
    setState(() {
      values[field.key] = result;
      controllers[field.key]!.text = result;
    });
  }

  void submit() {
    if (!form.currentState!.validate()) return;
    final result = <String, dynamic>{};
    for (final field in widget.fields) {
      var value = values[field.key];
      if (field.kind == FieldKind.number) {
        value = num.tryParse(controllers[field.key]!.text.trim());
      }
      if ([
        FieldKind.text,
        FieldKind.multiline,
        FieldKind.email,
      ].contains(field.kind)) {
        value = controllers[field.key]!.text.trim();
      }
      if (value != null && value != '') result[field.key] = value;
    }
    final message = widget.validate?.call(result);
    if (message != null) {
      setState(() => error = message);
      return;
    }
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : Form(
            key: form,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                for (final field in widget.fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: buildField(field),
                  ),
                if (error != null) ...[
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  TextButton(
                    onPressed: load,
                    child: Text(
                      context.tr('Reload options', 'Tải lại lựa chọn'),
                    ),
                  ),
                ],
                FilledButton(
                  onPressed: submit,
                  child: Text(context.tr('Continue', 'Tiếp tục')),
                ),
              ],
            ),
          ),
  );

  Widget buildField(FieldSpec field) {
    final label = context.tr(field.en, field.vi);
    final choices = options[field.key]!;
    String? requiredCheck(Object? value) =>
        field.required &&
            (value == null || value == '' || value is List && value.isEmpty)
        ? context.tr('Required field.', 'Thông tin bắt buộc.')
        : null;
    if (field.kind == FieldKind.toggle) {
      return FormField<bool>(
        initialValue: values[field.key] == true,
        validator: (value) => field.required && value != true
            ? context.tr('Confirmation is required.', 'Vui lòng xác nhận.')
            : null,
        builder: (state) => Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(label),
              value: state.value ?? false,
              onChanged: (value) {
                values[field.key] = value;
                state.didChange(value);
              },
            ),
            if (state.hasError)
              Text(
                state.errorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      );
    }
    if (field.kind == FieldKind.choice) {
      return DropdownButtonFormField<String>(
        initialValue: choices.containsKey(values[field.key])
            ? values[field.key] as String?
            : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: choices.entries
            .map(
              (entry) => DropdownMenuItem(
                value: entry.key,
                child: Text(entry.value, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: (value) => values[field.key] = value,
        validator: requiredCheck,
      );
    }
    if (field.kind == FieldKind.multiChoice) {
      return FormField<List<String>>(
        initialValue: (values[field.key] as List?)?.cast<String>() ?? [],
        validator: requiredCheck,
        builder: (state) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            for (final entry in choices.entries)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(entry.value),
                value: state.value!.contains(entry.key),
                onChanged: (checked) {
                  final selection = [...state.value!];
                  if (checked!) {
                    selection.add(entry.key);
                  } else {
                    selection.remove(entry.key);
                  }
                  values[field.key] = selection;
                  state.didChange(selection);
                },
              ),
            if (state.hasError)
              Text(
                state.errorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      );
    }
    final isDate =
        field.kind == FieldKind.date || field.kind == FieldKind.instant;
    return TextFormField(
      controller: controllers[field.key],
      readOnly: isDate,
      onTap: isDate ? () => pickDate(field) : null,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: isDate ? const Icon(Icons.calendar_today_outlined) : null,
      ),
      maxLines: field.kind == FieldKind.multiline ? 4 : 1,
      keyboardType: field.kind == FieldKind.number
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : field.kind == FieldKind.email
          ? TextInputType.emailAddress
          : TextInputType.text,
      validator: (value) {
        final requiredError = requiredCheck(value);
        if (requiredError != null) return requiredError;
        if (field.kind == FieldKind.number &&
            value != null &&
            value.isNotEmpty) {
          final number = num.tryParse(value);
          if (number == null ||
              !number.isFinite ||
              field.min != null && number < field.min! ||
              field.max != null && number > field.max!) {
            return context.tr(
              'Enter a valid number within the allowed range.',
              'Nhập số hợp lệ trong giới hạn.',
            );
          }
        }
        return null;
      },
    );
  }
}
