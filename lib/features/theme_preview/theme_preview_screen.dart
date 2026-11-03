// lib/features/theme_preview/theme_preview_screen.dart
//
// Step 0 review surface: shows every heritage token + component together so the
// theme can be verified visually (and against design/Sheikhi Design System.dc.html)
// before any real screen is built. Not shipped — used only via theme_preview_main.
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/girih_background.dart';
import '../../core/widgets/mihrab_arch.dart';
import '../../core/widgets/ornament_divider.dart';
import '../../core/widgets/sheikhy_badge.dart';
import '../../core/widgets/sheikhy_button.dart';
import '../../core/widgets/sheikhy_card.dart';
import '../../core/widgets/sheikhy_course_card.dart';
import '../../core/widgets/sheikhy_progress_bar.dart';
import '../../core/widgets/sheikhy_text_field.dart';
import '../../core/widgets/step_dots.dart';

class ThemePreviewScreen extends StatelessWidget {
  const ThemePreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Banner(),
            const _GoldRule(),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageGutter,
                vertical: AppSpacing.s6,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _PaletteSection(),
                  SizedBox(height: AppSpacing.s6),
                  OrnamentDivider(),
                  SizedBox(height: AppSpacing.s6),
                  _TypeSection(),
                  SizedBox(height: AppSpacing.s7),
                  _ButtonsSection(),
                  SizedBox(height: AppSpacing.s7),
                  _CardsSection(),
                  SizedBox(height: AppSpacing.s7),
                  _InputsProgressSection(),
                  SizedBox(height: AppSpacing.s7),
                  _PatternSection(),
                  SizedBox(height: AppSpacing.s8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Banner ───────────────────────────
class _Banner extends StatelessWidget {
  const _Banner();

  @override
  Widget build(BuildContext context) {
    // Content-sized (min 200) so the banner can never clip its title, whatever
    // the font metrics / text scale. The Stack sizes to the non-positioned
    // Padding child; the fills paint the background behind it.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 200),
      child: Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: AppColors.primary)),
          Positioned.fill(
            child: CustomPaint(
              painter: GirihPainter(color: AppColors.goldLight, opacity: 0.13),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.s5,
              AppSpacing.s7,
              AppSpacing.s5,
              AppSpacing.s5,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const MihrabArch(width: 26, height: 34),
                    const SizedBox(width: AppSpacing.s2),
                    Text('SHEIKHI · شيخي', style: AppTextStyles.brandLabel),
                  ],
                ),
                const SizedBox(height: AppSpacing.s3),
                Text(
                  'نظام التصميم — شيخي',
                  style: AppTextStyles.display.copyWith(
                    color: AppColors.inkInvert,
                    fontSize: 36,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoldRule extends StatelessWidget {
  const _GoldRule();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.gold, AppColors.goldLight, AppColors.gold],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}

// ─────────────────────────── Section shell ───────────────────────────
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.tag, required this.child});

  final String title;
  final String tag;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.s3,
          runSpacing: AppSpacing.s1,
          children: [
            Text(
              title,
              style: AppTextStyles.h2.copyWith(color: AppColors.primary),
            ),
            Text(tag, style: AppTextStyles.caption),
          ],
        ),
        const SizedBox(height: AppSpacing.s4),
        child,
      ],
    );
  }
}

// ─────────────────────────── Palette ───────────────────────────
class _PaletteSection extends StatelessWidget {
  const _PaletteSection();

  @override
  Widget build(BuildContext context) {
    final swatches = <_Swatch>[
      _Swatch('أساسي', AppColors.primary, 'primary'),
      _Swatch('أساسي غامق', AppColors.primaryDeep, 'primaryDeep'),
      _Swatch('أساسي فاتح', AppColors.primarySoft, 'primarySoft'),
      _Swatch('أساسي باهت', AppColors.primaryTint, 'primaryTint'),
      _Swatch('ذهبي', AppColors.gold, 'gold'),
      _Swatch('ذهبي فاتح', AppColors.goldLight, 'goldLight'),
      _Swatch('ورق', AppColors.paper, 'paper'),
      _Swatch('ورق غائر', AppColors.paperSunk, 'paperSunk'),
      _Swatch('حدود', AppColors.border, 'border'),
      _Swatch('نص أساسي', AppColors.ink, 'ink'),
      _Swatch('نص ثانوي', AppColors.inkMuted, 'inkMuted'),
      _Swatch('نص خفيف', AppColors.inkFaint, 'inkFaint'),
      _Swatch('نجاح', AppColors.success, 'success'),
      _Swatch('تنبيه', AppColors.warning, 'warning'),
      _Swatch('خطأ', AppColors.danger, 'danger'),
      _Swatch('معلومة', AppColors.info, 'info'),
    ];
    return _Section(
      title: 'لوحة الألوان',
      tag: '01 / Palette',
      child: Wrap(
        spacing: AppSpacing.s3,
        runSpacing: AppSpacing.s3,
        children: swatches,
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.name, this.color, this.token);

  final String name;
  final Color color;
  final String token;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: SheikhyCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 72,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadiusDirectional.only(
                  topStart: Radius.circular(AppRadii.lg),
                  topEnd: Radius.circular(AppRadii.lg),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.s3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTextStyles.small.copyWith(color: AppColors.ink),
                  ),
                  Text(
                    token,
                    style: AppTextStyles.caption,
                    textDirection: TextDirection.ltr,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Type ───────────────────────────
class _TypeSection extends StatelessWidget {
  const _TypeSection();

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'سلّم الخطوط',
      tag: '02 / Type',
      child: SheikhyCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('صحيح البخاري', style: AppTextStyles.display),
            const SizedBox(height: AppSpacing.s3),
            Text('أصول الفقه — المستوى الأول', style: AppTextStyles.h1),
            const SizedBox(height: AppSpacing.s2),
            Text('الدرس الثالث: تعريف الحكم', style: AppTextStyles.h2),
            const SizedBox(height: AppSpacing.s2),
            Text('مسائل الباب', style: AppTextStyles.h3),
            const SizedBox(height: AppSpacing.s3),
            Text(
              'مقاس المتن الأساسي لصفحات الكتب وشروح الدروس. طوله المريح بين ٦٠ و٧٥ حرفًا في السطر.',
              style: AppTextStyles.bodyLg,
            ),
            const SizedBox(height: AppSpacing.s2),
            Text(
              'النص العام في الواجهات: الوصف، التعليقات، وشرح الاختبار.',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppSpacing.s2),
            Text(
              'نص مساعد: أسماء الشيوخ، مدة الدرس، عدد الأسئلة.',
              style: AppTextStyles.small,
            ),
            const SizedBox(height: AppSpacing.s2),
            Text('تسميات، وسوم، وأرقام الصفحات', style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Buttons ───────────────────────────
class _ButtonsSection extends StatelessWidget {
  const _ButtonsSection();

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'الأزرار',
      tag: '04 / Buttons',
      child: SheikhyCard(
        child: Wrap(
          spacing: AppSpacing.s5,
          runSpacing: AppSpacing.s5,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('أساسي', style: AppTextStyles.caption),
                const SizedBox(height: AppSpacing.s3),
                SheikhyButton.primary(label: 'ابدأ الدرس', onPressed: () {}),
                const SizedBox(height: AppSpacing.s3),
                SheikhyButton.primary(
                  label: 'حجم صغير',
                  size: SheikhyButtonSize.sm,
                  onPressed: () {},
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ثانوي / نصّي', style: AppTextStyles.caption),
                const SizedBox(height: AppSpacing.s3),
                SheikhyButton.secondary(label: 'أضف للمكتبة', onPressed: () {}),
                const SizedBox(height: AppSpacing.s3),
                SheikhyButton.text(label: 'زر نصّي', onPressed: () {}),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('معطّل / تحميل', style: AppTextStyles.caption),
                const SizedBox(height: AppSpacing.s3),
                const SheikhyButton.primary(
                  label: 'الاختبار مُقفل',
                  onPressed: null,
                ),
                const SizedBox(height: AppSpacing.s3),
                SheikhyButton.primary(
                  label: 'يحفظ…',
                  isLoading: true,
                  onPressed: () {},
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('أيقوني', style: AppTextStyles.caption),
                const SizedBox(height: AppSpacing.s3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SheikhyIconButton(
                      icon: const Icon(Icons.play_arrow),
                      onPressed: () {},
                    ),
                    const SizedBox(width: AppSpacing.s2),
                    SheikhyIconButton(
                      icon: const Icon(Icons.bookmark_border),
                      filled: false,
                      onPressed: () {},
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Cards + badges ───────────────────────────
class _CardsSection extends StatelessWidget {
  const _CardsSection();

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'الكارت والشارات',
      tag: '05 / Card & Badge',
      child: Wrap(
        spacing: AppSpacing.s5,
        runSpacing: AppSpacing.s5,
        children: [
          SizedBox(
            width: 340,
            child: SheikhyCourseCard(
              title: 'شرح الأربعين النووية',
              meta: 'الشيخ عبد الله المنصور · ١٢ درسًا · ٤ س ٣٠ د',
              badges: const [
                SheikhyBadge(
                  variant: SheikhyBadgeVariant.audio,
                  label: 'فيديو',
                ),
              ],
              progress: 0.58,
              footerText: 'أنجزت ٧ من ١٢',
              ctaText: 'تابع',
              onTap: () {},
            ),
          ),
          SizedBox(
            width: 300,
            child: SheikhyCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SheikhyBadge(
                    variant: SheikhyBadgeVariant.certified,
                    label: 'كتاب',
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    'الآجُرُّومِيَّة',
                    style: AppTextStyles.display.copyWith(fontSize: 30),
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  Text(
                    'متن في النحو · ٦٤ صفحة · مع الشرح الصوتي',
                    style: AppTextStyles.small,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 300,
            child: SheikhyCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الشارات', style: AppTextStyles.caption),
                  const SizedBox(height: AppSpacing.s3),
                  Wrap(
                    spacing: AppSpacing.s2,
                    runSpacing: AppSpacing.s2,
                    children: const [
                      SheikhyBadge(variant: SheikhyBadgeVariant.isNew),
                      SheikhyBadge(variant: SheikhyBadgeVariant.passed),
                      SheikhyBadge(variant: SheikhyBadgeVariant.certified),
                      SheikhyBadge(variant: SheikhyBadgeVariant.draft),
                      SheikhyBadge(variant: SheikhyBadgeVariant.expired),
                      SheikhyBadge(variant: SheikhyBadgeVariant.audio),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Inputs + progress ───────────────────────────
class _InputsProgressSection extends StatelessWidget {
  const _InputsProgressSection();

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'الحقول والتقدّم',
      tag: '06 / Input & Progress',
      child: Wrap(
        spacing: AppSpacing.s5,
        runSpacing: AppSpacing.s5,
        children: [
          SizedBox(
            width: 380,
            child: SheikhyCard(
              child: Column(
                children: const [
                  SheikhyTextField(
                    label: 'اسم الطالب',
                    hintText: 'اكتب اسمك الكامل',
                    helperText: 'يظهر على الشهادة كما تكتبه',
                  ),
                  SizedBox(height: AppSpacing.s5),
                  SheikhyTextField(
                    label: 'البحث في المتون',
                    hintText: 'ابحث عن باب أو حديث…',
                    prefixIcon: Icon(Icons.search),
                  ),
                  SizedBox(height: AppSpacing.s5),
                  SheikhyTextField(
                    label: 'كود الالتحاق',
                    hintText: 'SK-0000',
                    errorText: 'الكود غير صحيح أو منتهي',
                  ),
                  SizedBox(height: AppSpacing.s5),
                  SheikhyTextField(
                    label: 'الحلقة الدراسية',
                    hintText: 'تُحدَّد بعد القبول',
                    enabled: false,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 380,
            child: SheikhyCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _progressRow('تقدّم المقرر', '٥٨٪'),
                  const SizedBox(height: AppSpacing.s2),
                  const SheikhyProgressBar(value: 0.58),
                  const SizedBox(height: AppSpacing.s5),
                  _progressRow('تقدّم ذهبي (الحفظ)', '٣١٪'),
                  const SizedBox(height: AppSpacing.s2),
                  const SheikhyProgressBar(
                    value: 0.31,
                    variant: SheikhyProgressVariant.gold,
                  ),
                  const SizedBox(height: AppSpacing.s5),
                  Text('خطوات الاختبار', style: AppTextStyles.fieldLabel),
                  const SizedBox(height: AppSpacing.s3),
                  const StepDots(total: 5, current: 3),
                  const SizedBox(height: AppSpacing.s3),
                  Text('السؤال ٣ من ٥', style: AppTextStyles.small),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.fieldLabel),
        Text(
          value,
          style: AppTextStyles.small.copyWith(color: AppColors.goldDeep),
        ),
      ],
    );
  }
}

// ─────────────────────────── Pattern ───────────────────────────
class _PatternSection extends StatelessWidget {
  const _PatternSection();

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'الزخارف والخلفيات',
      tag: '07 / Ornament',
      child: SheikhyCard(
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: AppRadii.rLg,
          child: ConstrainedBox(
            // Content-sized (min 170) so the caption can never clip.
            constraints: const BoxConstraints(minHeight: 170),
            child: Stack(
              children: [
                const Positioned.fill(child: GirihBackground(opacity: 0.14)),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.s5),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('خلفية girih', style: AppTextStyles.h3),
                      const SizedBox(height: AppSpacing.s2),
                      Text(
                        'وحدة ٥٦ · حدّ ١ · شفافية منخفضة\nلا تُستخدم أبدًا تحت متن قابل للقراءة.',
                        style: AppTextStyles.small,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
