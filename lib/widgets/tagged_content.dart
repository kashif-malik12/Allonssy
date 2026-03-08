import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/mention_service.dart';

class TaggedContent extends StatelessWidget {
  final String content;
  final TextStyle? textStyle;

  const TaggedContent({
    super.key,
    required this.content,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final parsed = MentionService.parseTaggedContent(content);
    if (parsed.tags.isEmpty) {
      return Text(parsed.body, style: textStyle);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: parsed.tags
              .map(
                (tag) => ActionChip(
                  backgroundColor: const Color(0xFFDDF1EB),
                  side: const BorderSide(color: Color(0xFF99CDBF)),
                  labelStyle: const TextStyle(
                    color: Color(0xFF0B5D56),
                    fontWeight: FontWeight.w700,
                  ),
                  label: Text(tag.name),
                  onPressed: () async {
                    var targetId = tag.userId;
                    if (targetId == null || targetId.isEmpty) {
                      final row = await Supabase.instance.client
                          .from('profiles')
                          .select('id')
                          .eq('full_name', tag.name)
                          .maybeSingle();
                      targetId = row?['id']?.toString();
                    }

                    if (targetId == null || targetId.isEmpty || !context.mounted) return;
                    context.push('/p/$targetId');
                  },
                ),
              )
              .toList(),
        ),
        if (parsed.body.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(parsed.body, style: textStyle),
        ],
      ],
    );
  }
}
