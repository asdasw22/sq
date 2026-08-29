# SmartGradeScanner

تطبيق iOS مكتوب بالكامل بلغة **Swift + SwiftUI** لمسح أوراق الإجابة
(Bubble Sheets / OMR) عبر الكاميرا، وتصحيحها تلقائياً، وحساب الدرجات،
باستخدام **Vision** (كشف حواف الورقة + OCR) و **CoreImage** (تصحيح
منظور الصورة).

## الفكرة الأساسية: تمبليت (Template) يتعامل مع أي صورة

بدل كتابة كود مخصص لكل شكل ورقة، بُني المشروع حول فكرة **ScanTemplate**:
ملف بيانات (JSON أو Swift struct) يصف مكان كل فقاعة إجابة وكل حقل نصي
بإحداثيات **منسّبة (0...1)** بدل بكسل ثابت. هذا يعني:

1. **نفس التمبليت يعمل مع أي صورة** لنفس الورقة، بغض النظر عن دقة
   الكاميرا أو زاوية التصوير أو الإضاءة - لأن أول خطوة في خط الأنابيب
   (`DocumentAligner`) تكتشف حواف الورقة عبر
   `VNDetectRectanglesRequest` ثم تُسوّي الصورة (`CIPerspectiveCorrection`)
   إلى نفس الحجم المرجعي الذي بُني عليه التمبليت. بعدها كل إحداثي
   منسّب يشير للمكان الصحيح تماماً.
2. **يمكن إنشاء تمبليتات جديدة لأوراق مختلفة تماماً** (عدد أسئلة مختلف،
   عدد خيارات مختلف، تخطيط أعمدة مختلف) من داخل التطبيق نفسه عبر
   `TemplateEditorView`، بدون الحاجة لأي كود إضافي - هذا ما يجعله
   "يتعامل معها وغيرها" كما طُلب.

## بنية المشروع

```
SmartGradeScanner/
├── App/
│   └── SmartGradeScannerApp.swift        نقطة الدخول
├── Models/
│   ├── ScanTemplate.swift                نموذج التمبليت + توليد شبكي تلقائي
│   └── GradeResult.swift                 نتيجة الطالب + مفتاح الإجابة
├── Services/
│   ├── DocumentAligner.swift             محاذاة أي صورة (Vision + CoreImage)
│   ├── BubbleDetector.swift              كشف الفقاعات المملوءة
│   ├── OCRService.swift                  قراءة الاسم/الرقم (Vision OCR)
│   ├── GradingEngine.swift               مقارنة الإجابات بالمفتاح وحساب الدرجة
│   ├── ScanPipeline.swift                يربط كل الخدمات في تدفق واحد
│   ├── PersistenceStores.swift           تخزين JSON محلي (قوالب/نتائج/مفاتيح)
│   └── CSVExporter.swift                 تصدير النتائج لملف CSV
├── Views/
│   ├── ContentView.swift                 التبويبات الرئيسية
│   ├── ScanHomeView.swift                اختيار القالب + المسح
│   ├── DocumentCameraView.swift          غلاف VisionKit للكاميرا + اختيار من المعرض
│   ├── ResultsView.swift                 عرض النتيجة + تراكب ملوّن + تصحيح يدوي
│   ├── TemplatesListView.swift           إدارة القوالب
│   ├── TemplateEditorView.swift          إنشاء قالب جديد لأي ورقة
│   ├── AnswerKeyEditorView.swift         تحديد الإجابات الصحيحة
│   ├── HistoryView.swift                 سجل كل الأوراق الممسوحة + بحث + تصدير
│   └── SettingsView.swift
├── Utilities/
│   └── Extensions.swift
└── Resources/
    ├── Templates/bubble_sheet_20q.json           تمبليت جاهز (20 سؤال، A-D)
    └── PrintableTemplates/bubble_sheet_20q.png   ورقة الإجابة المطابقة له تماماً، جاهزة للطباعة
```

## خط الأنابيب (Pipeline) خطوة بخطوة

```
صورة خام (كاميرا/معرض)
        │
        ▼
DocumentAligner   ← يكتشف حواف الورقة ويصحح المنظور إلى الحجم المرجعي
        │
        ▼
BubbleDetector    ← يقيس اسوداد كل فقاعة حسب إحداثيات التمبليت المنسّبة
        │
        ▼
OCRService        ← يقرأ اسم الطالب/رقمه من مناطق التمبليت النصية
        │
        ▼
GradingEngine     ← يقارن بمفتاح الإجابة ويحسب الدرجة
        │
        ▼
GradeResult محفوظ + قابل للمراجعة اليدوية من ResultsView
```

## إعداد المشروع في Xcode

**الطريقة الأسرع (موصى بها):** ثبّت [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(`brew install xcodegen`)، ثم شغّل `xcodegen generate` داخل مجلد
المشروع - سيُنشئ `SmartGradeScanner.xcodeproj` جاهزاً بكل الملفات
والأذونات مُعدّة تلقائياً من `project.yml`. افتحه في Xcode مباشرة.
هذه هي نفس الطريقة التي يستخدمها سير عمل GitHub Actions (أسفل).

**الطريقة اليدوية:**

1. أنشئ مشروع جديد: **File → New → Project → iOS App**، الاسم
   `SmartGradeScanner`، الواجهة **SwiftUI**، اللغة **Swift**، الحد
   الأدنى لنظام التشغيل **iOS 16**.
2. احذف الملفات الافتراضية (`ContentView.swift`, `...App.swift`) التي
   ينشئها Xcode تلقائياً.
3. اسحب مجلدات `App`، `Models`، `Services`، `Views`، `Utilities` بالكامل
   إلى المشروع في Xcode (اختر "Copy items if needed" و"Create groups").
4. اسحب مجلد `Resources/Templates` كـ **Folder Reference** (أيقونة
   زرقاء وليست صفراء) حتى يبقى بنية الملفات كما هي ويقدر
   `Bundle.main` يجدها بمسار `Templates/bubble_sheet_20q.json`.
5. أضف الأذونات التالية في **Info.plist**:
   - `NSCameraUsageDescription`: "نحتاج الكاميرا لمسح أوراق الإجابة"
   - `NSPhotoLibraryUsageDescription`: "لاختيار صورة ورقة إجابة من المعرض"
6. شغّل المشروع على جهاز حقيقي (الكاميرا لا تعمل جيداً على المحاكي
   لالتقاط صور واقعية، رغم أن كل شيء آخر يعمل على المحاكي).

## طباعة واستخدام التمبليت الجاهز

الملف `Resources/PrintableTemplates/bubble_sheet_20q.png` هو ورقة
إجابة **20 سؤال (A-D)** جاهزة للطباعة مباشرة، وإحداثياتها مطابقة
تماماً لملف `bubble_sheet_20q.json` (الاثنان تم توليدهما من نفس
سكربت بايثون `generate_template.py` لضمان التطابق). اطبعها، اجعل
الطلاب يملؤونها، ثم امسحها من التطبيق مباشرة.

## توليد أوراق/قوالب جديدة

- **من داخل التطبيق**: تبويب "القوالب" → زر "+" → حدد عدد الأسئلة،
  عدد الخيارات، عدد الأعمدة → حفظ. يُنشئ التطبيق قالباً جديداً برمجياً
  (`ScanTemplate.generateGrid`) بدون الحاجة لأي ورقة مطبوعة جاهزة
  مسبقاً - لكن حينها تحتاج لطباعة ورقة تطابق نفس الإحداثيات (يمكن
  توسيع `generateGrid` بسهولة لتصدير PNG مطابق تلقائياً بنفس منطق
  `generate_template.py`).
- **خارجياً**: عدّل `generate_template.py` (عدد الأسئلة، حجم الورقة،
  إلخ) وشغّله لتوليد زوج JSON + PNG جديد لأي تصميم ورقة تريده.

## البناء التلقائي عبر GitHub Actions (بدون جهاز Mac)

المشروع يحتوي الآن على:

- **`project.yml`**: مواصفات [XcodeGen](https://github.com/yonaskolb/XcodeGen)
  تولّد ملف `.xcodeproj` تلقائياً من مجلدات الكود، بدل الاحتفاظ بملف
  مشروع Xcode يدوي داخل Git (يسبب تعارضات دمج كثيرة). لاستخدامه محلياً:
  `brew install xcodegen && xcodegen generate` داخل مجلد المشروع.
- **`.github/workflows/build-ios-ipa.yml`**: سير عمل يبني التطبيق تلقائياً
  على كل `push` لفرع `main` (أو تشغيل يدوي من تبويب Actions)، باستخدام
  macOS runner من GitHub - فلا تحتاج جهاز Mac شخصي. الناتج ملف
  **`SmartGradeScanner-unsigned.ipa`** يظهر كـ Artifact قابل للتحميل من
  صفحة تشغيل الـ workflow.

  ⚠️ هذا الـ IPA **غير موقّع (Unsigned)** افتراضياً لأنه لا يوجد شهادة
  Apple Developer مُدخلة. لتثبيته على جهاز حقيقي مباشرة تحتاج إما:
  - إعادة توقيعه محلياً بحساب Apple ID شخصي عبر أداة مثل
    **Sideloadly** أو **AltStore**، أو
  - تفعيل خطوة التوقيع الاختيارية الموجودة (كتعليق) داخل ملف الـ
    workflow، بعد إضافة شهادة `.p12` وملف Provisioning Profile كـ
    Secrets في إعدادات المستودع (الخطوات موثّقة كتعليقات داخل الملف
    نفسه).

  خطوات الاستخدام: أنشئ مستودع GitHub جديد، ادفع (`push`) محتوى هذا
  المجلد كما هو (بما فيه `.github/`)، ثم افتح تبويب **Actions** في
  المستودع لمتابعة البناء وتحميل الـ IPA بعد اكتمال التشغيل.

## نقاط تطوير مستقبلية مقترحة

- دعم مسح **دفعة كاملة** من الأوراق (multi-page) دفعة واحدة بدل ورقة
  بورقة (البنية التحتية في `DocumentCameraView` تدعم `scan.pageCount`
  بالفعل - فقط استبدل `imageOfPage(at: 0)` بحلقة `for`).
- دعم شبكة فقاعات للرقم الجامعي (بدل OCR فقط) لدقة أعلى مع الأرقام.
- تصدير تقرير PDF لكل طالب بدل CSV فقط.
- مزامنة سحابية (iCloud / CloudKit) بدل التخزين المحلي فقط.
- تحرير رسومي كامل (سحب وإفلات الفقاعات) في `TemplateEditorView`
  بدل التوليد الشبكي التلقائي فقط.
