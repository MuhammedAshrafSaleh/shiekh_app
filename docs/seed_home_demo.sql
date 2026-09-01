-- docs/seed_home_demo.sql
-- بيانات تجريبية لمعاينة الصفحة الرئيسية للطالب (بانرات + كتب مميّزة).
-- شغّلها من Supabase SQL Editor. آمنة لإعادة التشغيل.
-- ملاحظة: لا تُحذف الأقسام (قد تكون مرتبطة بكتب أخرى)، تُعاد فقط بيانات الديمو.

begin;

-- تنظيف بيانات الديمو السابقة فقط (بحسب عناوين ثابتة)
delete from public.home_banners
 where title in ('دورة شرح الأصول الثلاثة', 'بث مباشر: مجلس العلم الأسبوعي');

-- حذف كتب الديمو (تُحذف دروسها تلقائيًا عبر ON DELETE CASCADE)
delete from public.books
 where title in ('كتاب التوحيد', 'عمدة الأحكام', 'تفسير ابن كثير');

-- 1) الأقسام: تُنشأ فقط إن لم تكن موجودة (لا حذف حتى لا نكسر كتبًا أخرى)
insert into public.sections (name, icon, description)
select v.name, v.icon, v.description
from (values
    ('العقيدة', 'mosque',    'مسائل التوحيد والإيمان'),
    ('الفقه',   'book',      'أحكام العبادات والمعاملات'),
    ('التفسير', 'menu_book', 'تفسير القرآن الكريم')
) as v(name, icon, description)
where not exists (
  select 1 from public.sections s where s.name = v.name
);

-- 2) الكتب المميّزة (منشورة + is_featured = true حتى تظهر في الرئيسية)
insert into public.books
  (section_id, title, description, cover_image_url, status, review_status, is_featured, featured_order)
select s.id, b.title, b.description, b.cover, 'published'::publish_status,
       'completed'::review_status, true, b.ord
from (values
  ('العقيدة', 'كتاب التوحيد',   'شرح مبسّط لكتاب التوحيد',   null::text, 1),
  ('الفقه',   'عمدة الأحكام',   'أحاديث الأحكام الفقهية',    null,       2),
  ('التفسير', 'تفسير ابن كثير', 'مختصر تفسير القرآن العظيم', null,       3)
) as b(section_name, title, description, cover, ord)
join public.sections s on s.name = b.section_name;

-- 3) دروس لكل كتاب (منشورة) حتى يظهر عدّاد "X درس" وشريط التقدّم
insert into public.lessons (book_id, order_index, title, status)
select bk.id, g.n, 'الدرس ' || g.n, 'published'::publish_status
from public.books bk
join lateral (
  select generate_series(1,
    case bk.title
      when 'كتاب التوحيد'   then 12
      when 'عمدة الأحكام'   then 24
      when 'تفسير ابن كثير' then 40
      else 5
    end) as n
) g on true
where bk.title in ('كتاب التوحيد', 'عمدة الأحكام', 'تفسير ابن كثير');

-- 4) بانرات الـ Carousel (is_active = true حتى تظهر)
insert into public.home_banners (title, description, image_url, linked_book_id, order_index, is_active)
values
  ('دورة شرح الأصول الثلاثة', 'الشيخ د. صالح الفوزان', null,
    (select id from public.books where title = 'كتاب التوحيد' limit 1), 0, true),
  ('بث مباشر: مجلس العلم الأسبوعي', 'كل يوم جمعة بعد العشاء', null,
    null, 1, true);

commit;
