# DESIGN_SYSTEM.md — شيخي (Sheikhi)

> **الغرض من الملف:** ده الدستور اللي يلتزم بيه Claude Code في كل شاشة أثناء الـredesign.
> بيقول **اعمل إيه وما تعملش إيه** — القواعد والمعمارية والـwhite-labeling.
> القيم البصرية نفسها (ألوان، خطوط، مسافات) الـsource of truth بتاعها هو `design_tokens.json`.
> لو حصل تعارض بين الملف ده والصورة، **الصورة تكسب** في الشكل، والملف ده يكسب في المعمارية والقواعد.

---

## 0. المبدأ الحاكم

الـredesign ده **بصري بحت**. إحنا بنغيّر شكل عرض الداتا، مش الداتا نفسها ولا المنطق.

- الشغل كله في طبقة `presentation/` + `core/theme/` + `core/widgets/`.
- **ممنوع منعًا باتًا** لمس أي ملف في `domain/` أو `data/`، أو أي `Bloc` / `Cubit` / `Repository` / `DataSource`.
- لو التصميم الجديد محتاج داتا مش موجودة في الـstate الحالي → **قف واسأل**. ما تعدّلش الـBloc عشان تجيب الداتا.
- التستات الموجودة لازم تفضل خضرا. لو تست وقع بسبب تغيير في الـUI، بلّغني قبل ما تعدّله.

---

## 1. الهوية البصرية (الروح)

تراث إسلامي **معاصر** — مش تراث حرفي قديم، ولا Material مسطّح عادي.

- مستوحى من: المخطوطات، الزخرفة الهندسية (girih)، الأرابيسك، والعقد المدبّب (قوس المحراب) في رؤوس الكروت والهيدرز.
- **الورق العاجي هو الخلفية، الأخضر المخطوطي هو الأساس، الذهب للحدود والزخارف فقط، والنص بنّي داكن — مش أسود.**
- **المحتوى هو البطل.** الزخرفة إطارات وفواصل وخلفيات خفيفة، مش عنصر مسيطر.
- RTL بالكامل، والقراءة الطويلة مريحة (line-height عالي).

### قواعد الزخرفة (صارمة)
1. **ممنوع أي رسم لكائن حي** (إنسان/حيوان/طير) — نهائيًا.
2. الزخرفة = إطارات + فواصل + خلفيات فقط.
3. **ممنوع أي pattern تحت نص قابل للقراءة.** الباترن يبقى في الهيدرز ورؤوس الكروت والخلفيات الفاضية بس.
4. شفافية الباترن واطية دايمًا: `0.10` على الورق، `0.14–0.16` على الأساسي.

---

## 2. الـWhite-Labeling — أهم قسم في الملف

التطبيق ده template. كل deployment لشيخ مختلف بلون مختلف. لو اتعامل الموضوع غلط، أول تغيير لون هيبوّظ التصميم كله.

### القواعد
- **`AppColors` ما فيهاش لون primary صريح.** الـprimary بييجي من `AppConfig.primaryColor`.
- الألوان اتقسّمت **أدوار**، مش أسماء ألوان:
  - **متغيّر لكل شيخ:** `primary`, `primaryDeep`, `primarySoft`, `primaryTint`
  - **ثابت (heritage base — مشترك بين كل الشيوخ):** الذهب، الورق، الحدود، النص، ألوان الحالة
- **قرار مقصود:** الذهب والورق **يفضلوا ثابتين** عبر كل الـdeployments. ده بيدّي هوية موحدة للـtemplate، والـprimary بس هو اللي بيميّز كل شيخ. ما تخليش الذهب متغيّر إلا لو طلبت ده صراحة.
- درجات الأساسي الغامق/الفاتح تتحسب **برمجيًا** من الـprimary (عن طريق `HSLColor` — تغميق/تفتيح)، مش تتكتب hex ثابت. كده أي primary جديد بيطلّع درجاته تلقائيًا.

### الزخارف SVG — مش PNG
- **كل الزخارف `flutter_svg`.** ممنوع PNG لأي عنصر زخرفي.
- السبب: الـSVG بيتلوّن برمجيًا بالـprimary. الـPNG بلون ذهبي/أخضر ثابت هيبوّظ أول ما تغيّر شيخ.
- الباترنات (girih / arabesque / mihrab arch) كلها أشكال SVG قابلة لإعادة الاستخدام مع `color` parameter.

---

## 3. طبقة الـTheme — أول حاجة تتبني (Step 0)

قبل أي شاشة. لو فيه غلطة هنا، هتتكرر في كل شاشة.

```
lib/core/theme/
  app_colors.dart        // أدوار الألوان (primary من AppConfig، الباقي ثابت)
  app_text_styles.dart   // سلّم الخطوط كامل
  app_spacing.dart       // سلّم المسافات 4pt
  app_radii.dart         // أنصاف الأقطار
  app_decorations.dart   // BoxDecoration للكروت والحقول + الظلال + البراويز
  app_theme.dart         // ThemeData يجمّع كل ده (light أساسًا)

lib/core/widgets/
  sheikhy_button.dart      // primary / secondary / text / icon + disabled + loading
  sheikhy_card.dart        // الكارت الأساسي (بحافة + ظل خفيف)
  sheikhy_course_card.dart // كارت بـmihrab head + باترن
  sheikhy_text_field.dart  // الحقل + label + helper + error state
  sheikhy_badge.dart       // الشارات بكل ألوانها
  ornament_divider.dart    // الفاصل الزخرفي الذهبي
  mihrab_arch.dart         // قوس المحراب SVG (reusable)
  girih_background.dart    // خلفية girih SVG بشفافية
  progress_bar.dart        // شريط التقدّم + التدرّج
  step_dots.dart           // نقاط خطوات الاختبار

lib/features/theme_preview/
  theme_preview_screen.dart // شاشة واحدة تعرض كل الـcomponents مع بعض
```

**`theme_preview_screen` مش رفاهية.** دي اللي بتخليك تشوف أي تعديل في الثيم على كل الـcomponents مرة واحدة. راجعها بعينك واقفل الثيم قبل ما تبدأ أي شاشة حقيقية.

---

## 4. التوكنز → Flutter (خريطة التحويل)

الـsource of truth هو `design_tokens.json`. ده تحويلها لـFlutter:

### الألوان
| التوكن | الدور في Flutter | متغيّر؟ |
|---|---|---|
| `primary.800` #1E4034 | `AppColors.primary` ← **من AppConfig** | ✅ متغيّر |
| `primary.900` #14291F | `AppColors.primaryDeep` ← يُحسب من primary | ✅ مشتق |
| `primary.600` #2F5F4C | `AppColors.primarySoft` ← يُحسب | ✅ مشتق |
| `primary.50` #EAF0EC | `AppColors.primaryTint` ← يُحسب | ✅ مشتق |
| `gold.500` #C09A4E | `AppColors.gold` | ⛔ ثابت |
| `gold.300` #E3CE9B | `AppColors.goldLight` | ⛔ ثابت |
| `gold.600` #8A6A2F | `AppColors.goldDeep` | ⛔ ثابت |
| `paper.base` #FBF7EF | `AppColors.paper` (خلفية الـScaffold) | ⛔ ثابت |
| `paper.sunk` #F1EADC | `AppColors.paperSunk` (خلفية الحقول) | ⛔ ثابت |
| `paper.raised` #FFFFFF | `AppColors.surface` (خلفية الكروت) | ⛔ ثابت |
| `border.base` #E4D9C4 | `AppColors.border` | ⛔ ثابت |
| `ink.base` #3B2E23 | `AppColors.ink` (النص الأساسي) | ⛔ ثابت |
| `ink.muted` #6B5B4B | `AppColors.inkMuted` | ⛔ ثابت |
| `ink.faint` #A2937F | `AppColors.inkFaint` (placeholder) | ⛔ ثابت |
| `state.danger` #8A3A2E | `AppColors.danger` (الـerror state) | ⛔ ثابت |
| `state.success` #2E6B4F | `AppColors.success` | ⛔ ثابت |
| `state.warning` #9A6B23 | `AppColors.warning` | ⛔ ثابت |
| `state.info` #3D5A80 | `AppColors.info` | ⛔ ثابت |

### الخطوط (Google Fonts — عربي)
| الدور | الخط | الاستخدام |
|---|---|---|
| `display` | **Aref Ruqaa** | المناسبات الاحتفالية فقط: أسماء الكتب، الشهادات |
| `heading` | **Reem Kufi** | كل العناوين h1–h3 + نصوص الأزرار |
| `body` | **Tajawal** (fallback: IBM Plex Sans Arabic) | كل المتن والنصوص العادية |

سلّم الأحجام (logical px = sp في Flutter): `display 56 · h1 40 · h2 32 · h3 24 · body-lg 19 · body 17 · small 15 · caption 13`
line-heights: العناوين `1.3–1.4` · المتن `1.8` · body-lg `1.85`.
**مهم:** استخدم `google_fonts` package، أو أضف الخطوط كـassets. تأكد إن الوزن المطلوب متحمّل (Reem Kufi 400–700، Tajawal 300–800، Aref Ruqaa 400/700).

### المسافات (4pt base)
`space-1=4 · 2=8 · 3=12 · 4=16 · 5=24 · 6=32 · 7=48 · 8=64 · 9=96`
هوامش الصفحة على الجوال: **24**.

### أنصاف الأقطار
`sm=6 · md=10 · lg=16 · xl=24 · pill=999`. رؤوس الكروت المميزة: قوس المحراب (SVG).

### الأبعاد الثابتة
- ارتفاع الزر الأساسي: **48** · الصغير: **38**
- ارتفاع الحقل: **48**
- أقل touch target: **44**
- ارتفاع شريط التقدّم: **10**
- عرض الحدود: hairline `1` · حقول/أزرار `1.5` · تأكيد `4`

### الظلال
- كارت: `0 2px 10px rgba(59,46,35,0.05)` (ناعم جدًا)
- مرفوع: `0 6px 24px rgba(59,46,35,0.09)`
> الظل خفيف دايمًا. ده تصميم ورقي مسطّح، مش Material فيه elevation قوي.

---

## 5. مواصفات الـComponents

### الزر (`SheikhyButton`)
- **primary:** خلفية `primary`، نص `paper` (فاتح)، حافة `primaryDeep`، radius `md`(10)، ارتفاع 48، خط Reem Kufi 17. فيه inset highlight ذهبي خفيف من فوق.
- **secondary:** خلفية `paper`، نص `primary`، حافة ذهبية `1.5`.
- **text:** بدون خلفية، نص `goldDeep`، أندرلاين ذهبي خفيف بمسافة تحت.
- **icon:** مربّع 48×48.
- **disabled:** خلفية `paperSunk`، نص `inkFaint`، مفيش تفاعل.
- **loading:** يعرض spinner صغير مكان النص، الزر يفضل بعرضه.

### الحقل (`SheikhyTextField`)
- label فوق (Tajawal 14.5 medium، لون `ink`)
- الحقل: خلفية `paperSunk`، حافة `border` بعرض `1.5`، radius `md`(10)، ارتفاع 48، padding أفقي 14.
- **focus:** الحافة تبقى ذهبية `gold`، الخلفية تبقى `surface` (أبيض).
- helper تحت (13، لون `inkFaint`).
- **error state:** الـlabel + الحافة + الـhelper كلهم `danger`، والخلفية وردية خفيفة `#FDF3F1`. ده أهم state لشاشات الـAuth.

### الكارت (`SheikhyCard`)
- خلفية `surface`، حافة `border` hairline، radius `lg`(16)، ظل الكارت الخفيف.
- **كارت المقرر (`SheikhyCourseCard`):** رأس بارتفاع ~150 بخلفية `primary` + باترن أرابيسك (opacity .16) + قوس محراب SVG في الركن + شارات فوق. الجسم أبيض بعنوان Reem Kufi + سطر ميتا + فوتر بحدّ علوي فيه progress/CTA.

### الشارة (`SheikhyBadge`)
أنواع بألوان الحالة: `جديد`(ذهبي فاتح/نص غامق) · `مُجتاز`(success/فاتح) · `مُجاز`(ذهبي محاط) · `مسودة`(paperSunk/muted) · `انتهت المدة`(danger/فاتح) · `صوتي`(info خفيف). كلها radius `pill`.

### الفاصل الزخرفي (`OrnamentDivider`)
خطين متدرّجين (transparent → border) وفي النص شكل SVG ذهبي (معيّنات + دوائر). يتمدّد بعرض المتاح.

### شريط التقدّم (`ProgressBar`)
خلفية `paperSunk`، حافة hairline، radius pill، ارتفاع 10. التعبئة تدرّج `primary → primarySoft`. نسخة "ذهبية" للحفظ: تدرّج `gold → goldLight`.

### قوس المحراب (`MihrabArch`) وخلفية girih (`GirihBackground`)
SVG reusable بـ`color` parameter. المحراب لرؤوس الكروت والهيدرز. الـgirih خلفية بشفافية واطية — **مش تحت نص**.

---

## 6. قواعد الكود (Flutter)

- **معمارية:** feature-first، Clean Architecture، Repository → Cubit/Bloc، `dartz Either`، `RepositoryProvider` للـDI، GoRouter. (زي ما المشروع ماشي — ما تغيّرش المعمارية.)
- **ممنوع styling inline في الشاشات.** أي لون/مسافة/خط يتاخد من `AppColors`/`AppSpacing`/`AppTextStyles` أو من component جاهز.
- لو شاشة محتاجة عنصر مش موجود في `core/widgets` → **اعمله component reusable الأول** في `core/widgets`، وقولّي إنه جديد، وبعدين استخدمه. ما تكتبوش inline جوه الشاشة.
- كل الأرقام (padding, radius, height) تيجي من التوكنز، مش hard-coded.
- RTL: اعتمد على `Directionality` + `EdgeInsetsDirectional` + `start/end` بدل `left/right`.
- الأرقام العربية-الهندية (٠١٢٣) في العرض للمستخدم لو ده اللي في التصميم.

---

## 7. حالات الشاشة (لا تُنسى)

كل شاشة فيها داتا لازم يتعمل ليها ٣ حالات مش الحالة المثالية بس:
- **loading:** skeleton بلون `paperSunk` (مش spinner في النص لو ممكن).
- **empty:** رسم زخرفي خفيف (SVG) + عنوان + سطر توضيحي + CTA لو مناسب. مايبقاش صفحة بيضا.
- **error:** رسالة واضحة + زر إعادة محاولة.

لشاشات الـAuth تحديدًا: الـerror state بتاع الحقول (حافة danger + رسالة تحت) لازم يتنفّذ من أول شاشة.

---

## 8. الـWorkflow (إلزامي)

1. **خطة الأول، كود بعدين.** اعرض الخطة وقف. ما تكتبش كود لحد ما أوافق.
2. شاشة **واحدة** في المرة. مش كل الشاشات مع بعض.
3. بعد كل شاشة: قف للمراجعة قبل اللي بعدها.
4. Step 0 (الثيم) يتقفل ويتراجع في `theme_preview` قبل أي شاشة حقيقية.
5. لو ظهرت مشكلة في الثيم أثناء شاشة → عدّل التوكن/الـcomponent المركزي، مش الشاشة.

### ترتيب الشاشات
**Step 0:** Theme + core widgets → **1:** Splash → **2:** Login → **3:** Create Account → **4:** Reset Password → **5:** Confirm Reset Password.

---

## 9. QA Checklist لكل شاشة

- [ ] RTL سليم (مفيش عنصر مقلوب أو ناحية غلط)
- [ ] الخط العربي مش مقطوع، والأوزان محمّلة صح
- [ ] الألوان كلها من `AppColors` (مفيش hex في الشاشة)
- [ ] الـcontrast مقبول (الذهبي **مش** على خلفية فاتحة كنص أساسي — الذهبي للحدود والزخارف بس)
- [ ] الـerror / empty / loading متعملين
- [ ] جرّبت بـprimary تاني (غيّر `AppConfig.primaryColor` مؤقتًا) — التصميم مايبوظش
- [ ] مفيش Bloc/Repository اتلمس
- [ ] الزخارف SVG (مفيش PNG زخرفي)

---

## 10. حدود صارمة (ملخّص الممنوعات)

1. ⛔ لمس أي شيء في `domain/` أو `data/` أو أي Bloc/Repository.
2. ⛔ لون primary صريح في الكود — دايمًا من `AppConfig`.
3. ⛔ PNG لأي زخرفة — SVG بس.
4. ⛔ styling inline في الشاشات — components وتوكنز بس.
5. ⛔ رسم كائنات حية.
6. ⛔ باترن تحت نص قابل للقراءة.
7. ⛔ كتابة كود قبل الموافقة على الخطة.
8. ⛔ أكتر من شاشة في المرة.
