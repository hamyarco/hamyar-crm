# توسعهٔ این نصب ویتایگر

این سند دو چیز را کنار هم می‌گذارد: مستندات رسمی توسعهٔ ویتایگر، و آنچه با بررسی **خود این
نصب** (نسخهٔ ۸.۴.۰ روی `/opt/hamyar-crm/html`) تأیید شد. هرجا مستندات رسمی با واقعیت این
نصب فرق داشت، واقعیت نوشته شده است.

منابع: [Developer Guide](https://community.vtiger.com/help/vtigercrm/developers/index.html) ·
[Develop Extensions](https://community.vtiger.com/help/vtigercrm/developers/develop-extensions-for-vtiger.html) ·
[Internals](https://community.vtiger.com/help/vtigercrm/developers/extensions/internals.html) ·
[vtlib](https://community.vtiger.com/help/vtigercrm/developers/vtlib/index.html) ·
[Server APIs](https://community.vtiger.com/help/vtigercrm/developers/server-apis.html) ·
[نمونهٔ ماژول](https://community.vtiger.com/help/vtigercrm/developers/extensions/examples/extension-module.html)

---

## ۰) اول از همه: کجا می‌شود دست زد و کجا نه

این مهم‌ترین بخش این سند است. فروشندهٔ فارسی‌ساز بخش‌هایی از کد را با PCG رمزگذاری کرده.
نقشهٔ دقیقش (شمارش‌شده روی همین نصب):

| جا | وضعیت |
|---|---|
| `vtlib/` (۶۴ فایل) | **دست‌نخورده و استاندارد** |
| `includes/` (۱۸ فایل) | **دست‌نخورده** |
| `libraries/` (۴۷۵ فایل) | **دست‌نخورده** |
| `layouts/` | **دست‌نخورده** |
| `include/` | فقط **یک** فایل رمزگذاری‌شده: `include/utils/jdf.php` (توابع تاریخ جلالی) |
| `languages/fa_ir/` | ۲۳۱ از ۲۳۵ فایل **رمزگذاری‌شده** — همان فارسی‌ساز |
| `languages/custom/` | ۴۰ فایل رمزگذاری‌شده |
| `modules/` | ۱۷۴۶ از ۳۴۶۲ فایل رمزگذاری‌شده — تقریباً همه‌اش ماژول‌های **خریداری‌شده**: PDFMaker (۵۹۰)، ITS4YouLibrary (۲۸۰)، ITS4YouReports (۲۳۹)، ITS4YouImport (۲۲۸)، EMAILMaker (۷۲)، Cashflow4You، CreditNotes4You و بقیهٔ `*4You` |

یعنی: **هستهٔ ویتایگر تمیز و استاندارد است.** ماژول‌های اصلی مثل `Leads`، `Contacts`،
`Potentials`، `Calendar` و کل `modules/Vtiger/` رمزگذاری نشده‌اند و می‌شود رویشان کار کرد.

قواعدی که از این نتیجه می‌شود:

1. **هیچ‌وقت ویتایگر را آپدیت نکنید** — نه ارتقای نسخه، نه دکمهٔ Update، نه `composer update`،
   نه جایگزینی فایل از تاربال خام. جزئیات در `README.md`.
2. هیچ فایل رمزگذاری‌شده‌ای را ویرایش نکنید و سعی نکنید بازش کنید — کار نمی‌کند و لایسنس
   هم قفل دامنه است.
3. برای هر چیز تازه، **ماژول یا فایل جدید** بسازید؛ فایل موجود را کم‌تر دست بزنید.
4. قبل از هر تغییر: `/opt/hamyar-crm/backup.sh`.

---

## ۱) مسیر یک درخواست

همهٔ ترافیک از `index.php` می‌آید. دو جریان وجود دارد و تفاوتشان در خروجی است:

| پارامتر | کلاس | خروجی |
|---|---|---|
| `?module=Leads&view=List` | `modules/Leads/views/List.php` → `Leads_List_View` | HTML یا redirect |
| `?module=Leads&action=Save` | `modules/Leads/actions/Save.php` → `Leads_Save_Action` | JSON (برای Ajax) |

اگر ماژول کلاس خودش را نداشته باشد، `Vtiger_Loader::getComponentClassName()` به
`modules/Vtiger/views/List.php` یا `modules/Vtiger/actions/Save.php` **fallback** می‌کند —
در `includes/main/WebUI.php` خط ۱۸۳. یعنی برای خیلی کارها لازم نیست کلاس بسازید؛ هستهٔ
`Vtiger` جواب می‌دهد.

چرخهٔ عمر هر view/action:

```php
checkPermission($request)   // دسترسی؛ استثنا بندازید تا جلو نرود
preProcess($request)        // در درخواست‌های Ajax اجرا نمی‌شود — هدر صفحه
process($request)           // همیشه اجرا می‌شود — کار اصلی
postProcess($request)       // در Ajax اجرا نمی‌شود — فوتر
```

`Vtiger_Request` ورودی است (`$request->get('x')`, `->getModule()`) و برای action‌ها با
`Vtiger_Response` جواب می‌دهید (`$response->setResult([...])`).

---

## ۲) ساختار یک ماژول

```
modules/MyModule/
├── MyModule.php            کلاس اصلی + vtlib_handler() برای رویدادهای نصب
├── schema.xml              جدول‌های ماژول (هنگام نصب بسته)
├── views/List.php          MyModule_List_View
├── actions/Save.php        MyModule_Save_Action
├── models/Record.php       MyModule_Record_Model
└── handlers/               event handlerها

layouts/v7/modules/MyModule/
├── Index.tpl  List.tpl     قالب‌های Smarty
└── resources/MyModule.js   جاوااسکریپت

languages/fa_ir/MyModule.php   رشته‌های فارسی — فایل تازه، پس با فارسی‌ساز تداخل ندارد
languages/en_us/MyModule.php
```

نکته: در این نصب `layouts/v7` استفاده می‌شود (`vlayout` قدیمی و بلااستفاده است).

**برچسب‌های فارسی:** چون `languages/fa_ir/*` رمزگذاری‌شده است، رشته‌های جدید را **هرگز**
داخل آن فایل‌ها نبرید. برای ماژول خودتان یک `languages/fa_ir/MyModule.php` تازه بسازید —
ویتایگر هر فایل زبان را جدا می‌خواند، پس فایل جدید بی‌دردسر کنار فایل‌های رمزگذاری‌شده
می‌نشیند.

---

## ۳) دیتابیس

```php
$db = PearDatabase::getInstance();
$r  = $db->pquery('SELECT * FROM vtiger_x WHERE id=?', [$id]);   // همیشه پارامتری
while ($row = $db->fetchByAssoc($r)) { ... }
$db->query_result($r, 0, 'col');
$db->num_rows($r);
$db->getLastInsertID();
```

برای رکوردهای CRM مستقیم SQL نزنید مگر مجبور باشید — مستندات رسمی هم می‌گوید کوئری
مستقیم «discouraged» است چون **دسترسی‌ها و رویدادها و گردش‌کارها را دور می‌زند**. به‌جایش:

```php
$record = Vtiger_Record_Model::getInstanceById($crmid, 'Leads');
$record->set('lastname', 'x');
$record->save();          // دسترسی، رویداد و workflow همه اجرا می‌شوند
```

ساختار داده: هر رکورد یک ردیف در `vtiger_crmentity` دارد (`crmid`, `setype`, `deleted`,
`smownerid`, `modifiedtime`) به‌علاوهٔ ردیف در جدول‌های اختصاصی ماژول
(`vtiger_leaddetails`, `vtiger_leadaddress`, …). حذف در ویتایگر **نرم** است:
`vtiger_crmentity.deleted = 1`.

---

## ۴) رویدادها (Event Handlers)

بهترین نقطه برای افزودن منطق بدون دست‌زدن به هسته.

```php
include_once 'vtlib/Vtiger/Event.php';
if (Vtiger_Event::hasSupport()) {
    Vtiger_Event::register(
        'Leads',                                   // ماژول، یا 'all'
        'vtiger.entity.aftersave',
        'HamyarLeadHandler',
        'modules/Hamyar/handlers/LeadHandler.php'
    );
}
```

```php
class HamyarLeadHandler extends VTEventHandler {
    function handleEvent($eventName, $entityData) {
        if ($eventName === 'vtiger.entity.aftersave') {
            $moduleName = $entityData->getModuleName();
            $id         = $entityData->getId();
            $data       = $entityData->getData();
        }
    }
}
```

رویدادهایی که **در همین نصب واقعاً ثبت شده‌اند** (از `vtiger_eventhandlers`):

`vtiger.entity.beforesave` · `vtiger.entity.aftersave` · `vtiger.entity.aftersave.final` ·
`vtiger.entity.beforedelete` · `vtiger.entity.afterdelete` · `vtiger.entity.beforerestore` ·
`vtiger.entity.afterrestore` · `vtiger.entity.beforerelate` · `vtiger.entity.afterrelate` ·
`vtiger.batchevent.save` · `vtiger.batchevent.delete` · `vtiger.lead.convertlead` ·
`vtiger.picklist.afterrename` · `vtiger.picklist.afterdelete` · `vtiger.field.afterdelete` ·
`module.postinstall`

---

## ۵) کرون

هر کار زمان‌بندی‌شده یک ردیف در `vtiger_cron_task` دارد با `handler_file` که به یک فایل
`.service` اشاره می‌کند، مثلاً `cron/modules/Reports/ScheduleReports.service`. ستون‌ها:
`frequency` (ثانیه)، `status` (۰ غیرفعال، ۱ فعال، ۲ **در حال اجرا**)، `laststart`/`lastend`.

**تله:** اگر تسکی وسط اجرا بمیرد، `status` روی ۲ گیر می‌کند و **دیگر هرگز اجرا نمی‌شود** —
پیام `is already running. Skipping execution.`. دقیقاً همین اتفاق برای گزارش‌های
زمان‌بندی‌شده افتاده بود. قبل از باز کردن قفل، `next_trigger_time` عقب‌افتاده‌ها را جلو
ببرید وگرنه همه‌شان یک‌باره ایمیل می‌شوند.

**تلهٔ دوم:** `vtigercron.php` فقط زیر `fpm-fcgi` یا از CLI با `SERVER_SOFTWARE` ست‌شده کار
می‌کند. این کانتینر `apache2handler` است، پس صدا زدنش با curl **۲۰۰ می‌دهد و هیچ کاری
نمی‌کند**. اجرای درست:

```bash
docker exec -u www-data -e SERVER_SOFTWARE=cron -w /var/www/html hamyar-crm-crm-1 php -f vtigercron.php
```

---

## ۶) وب‌سرویس / API

`webservice.php` فعال است (تست شد: `?operation=getchallenge` → ۲۰۰) و هر ۲۲ کاربر
`accesskey` دارند. جریان احراز هویت:

```
GET  webservice.php?operation=getchallenge&username=<user>     → token
POST webservice.php  operation=login, username=<user>,
                     accessKey=md5(token + accesskey)           → sessionName
```

بعد با `sessionName`: `query`، `create`، `retrieve`، `revise`، `delete`، `describe`،
`listtypes`، `sync`، `convertlead`. کوئری‌ها نحو شبه‌SQL دارند و **حتماً باید با `;` تمام
شوند**:

```
operation=query&sessionName=<s>&query=select * from Leads where lastname='x' limit 0,10;
```

عملیات‌های موجود در `include/Webservices/` هستند (`Query.php`, `Create.php`, `Revise.php`,
`Delete.php`, `ConvertLead.php`, `GetUpdates.php`, …). برای API داخلی PHP همان توابع
`vtws_*` را صدا بزنید (`vtws_query`, `vtws_create`, `vtws_getWebserviceEntityId`) — اینها
دسترسی و رویدادها را رعایت می‌کنند.

---

## ۷) vtlib — ساختن ماژول با کد

```php
include_once 'vtlib/Vtiger/Module.php';
$m = new Vtiger_Module();
$m->name = 'MyModule';
$m->parent = 'Tools';      // منوی مقصد
$m->save();
$m->initTables();          // سه جدول پایهٔ یک ماژول entity

$block = new Vtiger_Block(); $block->label = 'LBL_INFO'; $m->addBlock($block);
$f = new Vtiger_Field(); $f->name='title'; $f->label='Title'; $f->uitype=1;
$f->column='title'; $f->columntype='VARCHAR(100)'; $block->addField($f);
```

APIهای دیگر vtlib: `Vtiger_Block`, `Vtiger_Field`, `Vtiger_Filter` (نماهای پیش‌فرض),
`Vtiger_Link` (دکمه/منو), `Vtiger_Event`, `Vtiger_Menu`, `Vtiger_Package` (خروجی/ورودی
بسته), `Vtiger_Utils::CreateTable()`.

`vtlib_handler($moduleName, $eventType)` در کلاس اصلی ماژول، رویدادهای چرخهٔ نصب را
می‌گیرد: `module.postinstall`, `module.disabled`, `module.enabled`, `module.preuninstall`.

---

## ۸) قالب و جاوااسکریپت

قالب‌ها Smarty هستند در `layouts/v7/modules/<Module>/*.tpl`. ترجمه در قالب:
`{vtranslate('LBL_X', $MODULE)}`.

افزودن JS/CSS از داخل view:

```php
public function getHeaderScripts(Vtiger_Request $request) {
    $scripts = parent::getHeaderScripts($request);
    return array_merge($scripts, $this->checkAndConvertJsScripts([
        'modules.MyModule.resources.MyModule',   // نسبی به layout
        '~libraries/x/x.js',                     // نسبی به ریشهٔ ویتایگر
    ]));
}
```

سمت کلاینت، فراخوانی action‌ها:

```js
AppConnector.request('module=MyModule&action=Save&x=1').then(function (r) { ... });
app.showModalWindow(html, callback);
```

---

## ۹) قواعد کار روی این سرور

```bash
cd /opt/hamyar-crm
docker compose ps
docker compose logs -f crm
docker exec -u www-data -w /var/www/html hamyar-crm-crm-1 php -l <file>   # lint
docker compose up -d --build crm        # فقط اگر Dockerfile/php.ini عوض شد
```

- فایل‌ها bind-mount هستند، پس ویرایش در `/opt/hamyar-crm/html` بلافاصله زنده است
  (opcache هر ۵ ثانیه revalidate می‌کند).
- مالکیت فایل‌های تازه: `chown 33:33` (همان `www-data` داخل کانتینر).
- کش ویتایگر بعد از تغییر قالب یا فیلد: `rm -rf html/cache/templates_c/* html/cache/vtlib/*`.
- قبل از هر کار: `/opt/hamyar-crm/backup.sh` — و یادتان باشد این بکاپ تنها نسخهٔ موجود از
  کد رمزگذاری‌شدهٔ خریداری‌شده است.
- **صفحهٔ سفید؟** سه علت همیشگی: mount نبودن `pcg/`، نرسیدن هدر
  `X-Forwarded-Proto: https`، یا خطای PHP که ویتایگر بلعیده. جزئیات در `README.md`.
