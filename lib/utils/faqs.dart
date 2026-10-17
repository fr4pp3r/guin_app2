/// Locale-aware FAQ content for the Barangay Assistant chatbot.
///
/// These entries are the single source of truth for two things:
///   1. the FAQ list rendered in `chatbot_screen.dart`, and
///   2. the grounding context sent to the `chatbot` AI task, so the assistant
///      never contradicts the answers the app itself displays.
///
/// FAQ text is localized per locale (English / Filipino / Cebuano) to match the
/// app's ARB translations. Unlike simple UI labels these are structured records
/// with per-locale matching [FaqEntry.keywords], so they live here rather than in
/// the ARB files. [faqsFor] resolves a locale code and falls back to English.
///
/// Answers deliberately avoid stating exact fees, processing times or
/// requirements: those are configured per barangay and shown in the app, so a
/// hardcoded number here would be wrong for most deployments.
library;

/// Stable, locale-independent grouping of FAQ entries. Not shown in the UI — it
/// is used to pick representative quick-start questions per category.
enum FaqCategory {
  documents,
  payment,
  incidents,
  verification,
  account,
  announcements,
  about,
}

class FaqEntry {
  const FaqEntry({
    required this.question,
    required this.answer,
    required this.category,
    this.keywords = const <String>[],
  });

  final String question;
  final String answer;
  final FaqCategory category;

  /// Extra lowercase terms that should match this entry in [matchFaq], beyond
  /// the words already present in [question]. Kept per-locale so citizens can
  /// ask in their own language.
  final List<String> keywords;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'question': question,
    'answer': answer,
    'category': category.name,
  };
}

// ---------------------------------------------------------------------------
// English
// ---------------------------------------------------------------------------

const List<FaqEntry> kFaqsEn = <FaqEntry>[
  FaqEntry(
    question: 'How do I request a barangay document?',
    answer:
        'Open Request Document from your dashboard, choose the document type, '
        'fill in the required details and submit. You can follow the progress '
        'anytime under My Requests.',
    category: FaqCategory.documents,
    keywords: <String>['request', 'apply', 'get document', 'clearance', 'document'],
  ),
  FaqEntry(
    question: 'What documents can I request?',
    answer:
        'Barangay Clearance, Certificate of Indigency, Barangay ID, Cedula, '
        'Business Clearance, Barangay Certification, Oath of Undertaking, '
        'Certificate of Good Moral Character and Certificate of Residency.',
    category: FaqCategory.documents,
    keywords: <String>['available', 'document types', 'list', 'options', 'kinds'],
  ),
  FaqEntry(
    question: 'How much does a document cost and how do I pay?',
    answer:
        'Not every document is paid. When a fee applies, the app shows the '
        'amount on your request. Pay it by GCash to the barangay number shown '
        'in the app, then upload a screenshot of the GCash receipt so the '
        'treasurer can verify it.',
    category: FaqCategory.payment,
    keywords: <String>['fee', 'price', 'cost', 'payment', 'gcash', 'receipt', 'pay'],
  ),
  FaqEntry(
    question: 'What do the request statuses mean?',
    answer:
        'Your request moves from payment (if required) to review, then to '
        'approval and release. Open the request in My Requests to see what the '
        'current status means and what happens next.',
    category: FaqCategory.documents,
    keywords: <String>['status', 'pending', 'approved', 'released', 'state'],
  ),
  FaqEntry(
    question: 'How long does processing take?',
    answer:
        'Processing time depends on the document and how quickly it is '
        'reviewed and signed by barangay staff, so the app does not promise a '
        'fixed number of days. You will get a notification as your request '
        'progresses.',
    category: FaqCategory.documents,
    keywords: <String>['how long', 'days', 'wait', 'duration', 'processing time'],
  ),
  FaqEntry(
    question: 'How do I get my released document?',
    answer:
        'Once your request is released, open it in My Requests and tap to view '
        'the signed PDF. From the viewer you can request a printable copy if '
        'you need to print it.',
    category: FaqCategory.documents,
    keywords: <String>['claim', 'download', 'release', 'print', 'pdf', 'get copy'],
  ),
  FaqEntry(
    question: 'How do I report an incident?',
    answer:
        'Open Report Incident from your dashboard, describe what happened, pick '
        'a category and priority, and attach a photo if you have one. You can '
        'also drop a map pin so responders can find the location.',
    category: FaqCategory.incidents,
    keywords: <String>['report', 'incident', 'complaint', 'blotter', 'reklamo'],
  ),
  FaqEntry(
    question: 'What if it is an emergency?',
    answer:
        'For an emergency, contact the barangay hotline or local emergency '
        'services directly right away. You can still file a report in the app '
        'afterwards for the record.',
    category: FaqCategory.incidents,
    keywords: <String>['emergency', 'urgent', 'danger', 'accident', 'help now'],
  ),
  FaqEntry(
    question: 'How do I check if a document is genuine?',
    answer:
        'Use Verify Document on your dashboard and scan the QR code printed on '
        'the document. The app will show whether it is valid, and whether it '
        'has expired or already been used.',
    category: FaqCategory.verification,
    keywords: <String>['verify', 'qr', 'authentic', 'fake', 'genuine', 'scan'],
  ),
  FaqEntry(
    question: 'Why was my account not approved yet?',
    answer:
        'New accounts need approval by barangay staff before you can log in. '
        'Approval is done manually, so give it some time; you will be notified '
        'once your registration is approved.',
    category: FaqCategory.account,
    keywords: <String>['account', 'registration', 'approve', 'login', 'pending'],
  ),
  FaqEntry(
    question: 'Where do I see barangay announcements?',
    answer:
        'Announcements from barangay officials appear on your dashboard and in '
        'the announcements feed. Tap an announcement to read the full post.',
    category: FaqCategory.announcements,
    keywords: <String>['announcement', 'news', 'bulletin', 'notice', 'update'],
  ),
  FaqEntry(
    question: 'What can this assistant help with?',
    answer:
        'I can answer questions about requesting documents, fees and payment, '
        'request statuses, incident reporting, announcements and verifying '
        'documents. I only give information — I cannot submit or approve '
        'anything for you.',
    category: FaqCategory.about,
    keywords: <String>[
      'who are you',
      'help',
      'assistant',
      'bot',
      'what can you do',
    ],
  ),
];

// ---------------------------------------------------------------------------
// Filipino
// ---------------------------------------------------------------------------

const List<FaqEntry> kFaqsFil = <FaqEntry>[
  FaqEntry(
    question: 'Paano ako hihiling ng dokumento sa barangay?',
    answer:
        'Buksan ang "Humiling ng Dokumento" sa iyong dashboard, piliin ang uri '
        'ng dokumento, punan ang mga kailangang detalye at i-submit. '
        'Masusubaybayan mo ang progreso sa "Aking mga Kahilingan".',
    category: FaqCategory.documents,
    keywords: <String>[
      'hiling',
      'humiling',
      'dokumento',
      'kumuha',
      'clearance',
      'document',
      'request',
    ],
  ),
  FaqEntry(
    question: 'Anong mga dokumento ang maaari kong hilingin?',
    answer:
        'Barangay Clearance, Certificate of Indigency, Barangay ID, Cedula, '
        'Business Clearance, Barangay Certification, Oath of Undertaking, '
        'Certificate of Good Moral Character at Certificate of Residency.',
    category: FaqCategory.documents,
    keywords: <String>['anong dokumento', 'mga uri', 'listahan', 'options', 'ano ang available'],
  ),
  FaqEntry(
    question: 'Magkano ang isang dokumento at paano ako magbabayad?',
    answer:
        'Hindi lahat ng dokumento ay may bayad. Kapag may bayad, ipapakita ng '
        'app ang halaga sa iyong kahilingan. Magbayad sa pamamagitan ng GCash '
        'sa numerong nasa app, pagkatapos i-upload ang screenshot ng resibo ng '
        'GCash para ma-verify ng treasurer.',
    category: FaqCategory.payment,
    keywords: <String>['magkano', 'bayad', 'presyo', 'halaga', 'gcash', 'resibo', 'payment'],
  ),
  FaqEntry(
    question: 'Ano ang ibig sabihin ng mga status ng kahilingan?',
    answer:
        'Dumadaan ang iyong kahilingan mula sa bayad (kung kailangan) patungo '
        'sa pagsusuri, pagkatapos sa pag-apruba at paglabas. Buksan ang '
        'kahilingan sa "Aking mga Kahilingan" para makita ang kahulugan ng '
        'kasalukuyang status.',
    category: FaqCategory.documents,
    keywords: <String>['status', 'kalagayan', 'pending', 'approved', 'released'],
  ),
  FaqEntry(
    question: 'Gaano katagal ang pagproseso?',
    answer:
        'Depende ang tagal sa dokumento at sa bilis ng pagsusuri at pagpirma ng '
        'mga kawani ng barangay, kaya hindi nagsasaad ang app ng tiyak na '
        'bilang ng araw. Makakatanggap ka ng notification habang umuusad ang '
        'iyong kahilingan.',
    category: FaqCategory.documents,
    keywords: <String>['gaano katagal', 'araw', 'tagal', 'hintay', 'processing'],
  ),
  FaqEntry(
    question: 'Paano ko makukuha ang na-release kong dokumento?',
    answer:
        'Kapag na-release na ang kahilingan, buksan ito sa "Aking mga '
        'Kahilingan" at i-tap para makita ang pinirmahang PDF. Mula sa viewer, '
        'maaari kang humiling ng printable copy kung kailangan mong i-print.',
    category: FaqCategory.documents,
    keywords: <String>['kuha', 'download', 'release', 'print', 'pdf', 'kopya'],
  ),
  FaqEntry(
    question: 'Paano ako mag-uulat ng insidente?',
    answer:
        'Buksan ang "Iulat ang Insidente" sa iyong dashboard, ilarawan ang '
        'nangyari, pumili ng kategorya at priyoridad, at mag-attach ng larawan '
        'kung mayroon. Maaari ka ring maglagay ng pin sa mapa para mahanap ng '
        'mga responder ang lokasyon.',
    category: FaqCategory.incidents,
    keywords: <String>['ulat', 'iulat', 'insidente', 'reklamo', 'complaint', 'report'],
  ),
  FaqEntry(
    question: 'Paano kung emergency ito?',
    answer:
        'Sa emergency, agad na tumawag sa barangay hotline o sa local emergency '
        'services. Maaari mo pa ring mag-file ng ulat sa app pagkatapos para sa '
        'rekord.',
    category: FaqCategory.incidents,
    keywords: <String>['emergency', 'apurahan', 'panganib', 'aksidente', 'tulong'],
  ),
  FaqEntry(
    question: 'Paano ko malalaman kung tunay ang isang dokumento?',
    answer:
        'Gamitin ang "I-verify ang Dokumento" sa iyong dashboard at i-scan ang '
        'QR code na nakalagay sa dokumento. Ipapakita ng app kung ito ay valid, '
        'at kung nag-expire na o nagamit na.',
    category: FaqCategory.verification,
    keywords: <String>['verify', 'i-verify', 'qr', 'tunay', 'peke', 'scan'],
  ),
  FaqEntry(
    question: 'Bakit hindi pa naaaprubahan ang aking account?',
    answer:
        'Kailangan munang aprubahan ng kawani ng barangay ang mga bagong '
        'account bago ka makapag-login. Manu-manong ginagawa ang pag-apruba, '
        'kaya bigyan ito ng oras; aabisuhan ka kapag naaprubahan na ang iyong '
        'rehistro.',
    category: FaqCategory.account,
    keywords: <String>['account', 'rehistro', 'apruba', 'login', 'pending'],
  ),
  FaqEntry(
    question: 'Saan ko makikita ang mga anunsyo ng barangay?',
    answer:
        'Lumalabas ang mga anunsyo mula sa mga opisyal ng barangay sa iyong '
        'dashboard at sa feed ng mga anunsyo. I-tap ang anunsyo para mabasa ang '
        'buong post.',
    category: FaqCategory.announcements,
    keywords: <String>['anunsyo', 'balita', 'notice', 'update', 'announcement'],
  ),
  FaqEntry(
    question: 'Sa ano makakatulong ang assistant na ito?',
    answer:
        'Masasagot ko ang mga tanong tungkol sa paghiling ng dokumento, bayad '
        'at pagbabayad, status ng kahilingan, pag-uulat ng insidente, mga '
        'anunsyo at pag-verify ng dokumento. Impormasyon lang ang ibinibigay ko '
        '— hindi ako makakapag-submit o makakapag-apruba para sa iyo.',
    category: FaqCategory.about,
    keywords: <String>[
      'sino ka',
      'tulong',
      'assistant',
      'bot',
      'ano ang kaya mong gawin',
    ],
  ),
];

// ---------------------------------------------------------------------------
// Cebuano
// ---------------------------------------------------------------------------

const List<FaqEntry> kFaqsCeb = <FaqEntry>[
  FaqEntry(
    question: 'Unsaon nako paghangyo og dokumento sa barangay?',
    answer:
        'Ablihi ang "Maghangyo og Dokumento" sa imong dashboard, pilia ang '
        'matang sa dokumento, pun-a ang gikinahanglang detalye ug i-submit. '
        'Masubay nimo ang progreso sa "Akong mga Hangyo".',
    category: FaqCategory.documents,
    keywords: <String>[
      'hangyo',
      'paghangyo',
      'dokumento',
      'kuha',
      'clearance',
      'document',
      'request',
    ],
  ),
  FaqEntry(
    question: 'Unsa nga mga dokumento ang mahimo nakong hangyuon?',
    answer:
        'Barangay Clearance, Certificate of Indigency, Barangay ID, Cedula, '
        'Business Clearance, Barangay Certification, Oath of Undertaking, '
        'Certificate of Good Moral Character ug Certificate of Residency.',
    category: FaqCategory.documents,
    keywords: <String>['unsa nga dokumento', 'mga matang', 'lista', 'options', 'available'],
  ),
  FaqEntry(
    question: 'Pila ang bayad sa dokumento ug unsaon nako pagbayad?',
    answer:
        'Dili tanan nga dokumento naay bayad. Kung naay bayad, ipakita sa app '
        'ang kantidad sa imong hangyo. Pagbayad pinaagi sa GCash sa numero nga '
        'naa sa app, dayon i-upload ang screenshot sa resibo sa GCash aron '
        'ma-verify sa treasurer.',
    category: FaqCategory.payment,
    keywords: <String>['pila', 'bayad', 'presyo', 'gcash', 'resibo', 'payment'],
  ),
  FaqEntry(
    question: 'Unsa ang gipasabot sa mga status sa hangyo?',
    answer:
        'Moagi ang imong hangyo gikan sa bayad (kung gikinahanglan) ngadto sa '
        'review, dayon sa approval ug release. Ablihi ang hangyo sa "Akong mga '
        'Hangyo" aron makita ang gipasabot sa kasamtangang status.',
    category: FaqCategory.documents,
    keywords: <String>['status', 'kahimtang', 'pending', 'approved', 'released'],
  ),
  FaqEntry(
    question: 'Pila ka adlaw ang pagproseso?',
    answer:
        'Ang gidugayon nagdepende sa dokumento ug sa kapaspas sa pag-review ug '
        'pagpirma sa mga staff sa barangay, busa wala magsaad ang app og '
        'tukmang gidaghanon sa adlaw. Makadawat ka og notification samtang '
        'molambo ang imong hangyo.',
    category: FaqCategory.documents,
    keywords: <String>['pila ka adlaw', 'adlaw', 'dugay', 'hulat', 'processing'],
  ),
  FaqEntry(
    question: 'Unsaon nako pagkuha ang na-release nga dokumento?',
    answer:
        'Kung na-release na ang hangyo, ablihi kini sa "Akong mga Hangyo" ug '
        'i-tap aron makita ang pinirmahang PDF. Gikan sa viewer, makahangyo ka '
        'og printable copy kung kinahanglan nimo i-print.',
    category: FaqCategory.documents,
    keywords: <String>['kuha', 'download', 'release', 'print', 'pdf', 'kopya'],
  ),
  FaqEntry(
    question: 'Unsaon nako pagreport og insidente?',
    answer:
        'Ablihi ang "Ireport ang Insidente" sa imong dashboard, ihulagway ang '
        'nahitabo, pagpili og kategorya ug prayoridad, ug pag-attach og litrato '
        'kung naa. Mahimo pud ka magbutang og pin sa mapa aron makita sa mga '
        'responder ang lokasyon.',
    category: FaqCategory.incidents,
    keywords: <String>['report', 'insidente', 'reklamo', 'complaint', 'sumiter'],
  ),
  FaqEntry(
    question: 'Unsa kung emergency kini?',
    answer:
        'Kung emergency, tawag dayon sa barangay hotline o sa local emergency '
        'services. Mahimo gihapon ka mag-file og report sa app pagkahuman alang '
        'sa rekord.',
    category: FaqCategory.incidents,
    keywords: <String>['emergency', 'dinalian', 'katalagman', 'aksidente', 'tabang'],
  ),
  FaqEntry(
    question: 'Unsaon nako pag-verify kung tinuod ang dokumento?',
    answer:
        'Gamita ang "I-verify ang Dokumento" sa imong dashboard ug i-scan ang '
        'QR code nga naa sa dokumento. Ipakita sa app kung valid kini, ug kung '
        'na-expire na o nagamit na.',
    category: FaqCategory.verification,
    keywords: <String>['verify', 'i-verify', 'qr', 'tinuod', 'peke', 'scan'],
  ),
  FaqEntry(
    question: 'Ngano wala pa ma-approve ang akong account?',
    answer:
        'Kinahanglan una ma-approve sa staff sa barangay ang bag-ong account '
        'before ka makalogin. Manual ang pag-approve, busa hatagi og panahon; '
        'pahibaloon ka kung ma-approve na ang imong rehistro.',
    category: FaqCategory.account,
    keywords: <String>['account', 'rehistro', 'approve', 'login', 'pending'],
  ),
  FaqEntry(
    question: 'Asa nako makita ang mga announcement sa barangay?',
    answer:
        'Makita ang mga announcement gikan sa mga opisyal sa barangay sa imong '
        'dashboard ug sa feed sa mga announcement. I-tap ang announcement aron '
        'mabasa ang tibuok post.',
    category: FaqCategory.announcements,
    keywords: <String>['announcement', 'balita', 'notice', 'update', 'pahibalo'],
  ),
  FaqEntry(
    question: 'Unsa ang matabang niining assistant?',
    answer:
        'Matubag nako ang mga pangutana bahin sa paghangyo og dokumento, bayad '
        'ug pagbayad, status sa hangyo, pagreport og insidente, mga '
        'announcement ug pag-verify sa dokumento. Impormasyon lang ang akong '
        'gihatag — dili ko makasubmit o maka-approve alang nimo.',
    category: FaqCategory.about,
    keywords: <String>[
      'kinsa ka',
      'tabang',
      'assistant',
      'bot',
      'unsa ang kaya nimo',
    ],
  ),
];

/// Resolves the FAQ list for a locale code (`en`, `fil`, `ceb`). Unknown or null
/// codes fall back to English, matching the app's ARB fallback behaviour.
List<FaqEntry> faqsFor(String? languageCode) {
  switch (languageCode) {
    case 'fil':
      return kFaqsFil;
    case 'ceb':
      return kFaqsCeb;
    default:
      return kFaqsEn;
  }
}

/// Representative quick-start questions (one per core category) for the
/// assistant's opening suggestion chips, localized for [languageCode].
List<String> welcomeSuggestionsFor(String? languageCode) {
  const wanted = <FaqCategory>[
    FaqCategory.documents,
    FaqCategory.payment,
    FaqCategory.incidents,
  ];
  final faqs = faqsFor(languageCode);
  final suggestions = <String>[];
  for (final category in wanted) {
    for (final faq in faqs) {
      if (faq.category == category) {
        suggestions.add(faq.question);
        break;
      }
    }
  }
  return suggestions;
}

/// Very small keyword matcher used as an offline fallback when the AI is
/// unavailable. Pass [faqs] directly, or [languageCode] to match against the
/// localized list. Returns the best-scoring entry, or null when nothing matches
/// confidently. Pure and unit-testable — no Supabase, no AI.
FaqEntry? matchFaq(
  String query, {
  List<FaqEntry>? faqs,
  String? languageCode,
}) {
  final entries = faqs ?? faqsFor(languageCode);
  final normalized = query.toLowerCase().trim();
  if (normalized.isEmpty) return null;

  FaqEntry? best;
  var bestScore = 0;
  for (final faq in entries) {
    var score = 0;
    for (final keyword in faq.keywords) {
      if (keyword.isNotEmpty && normalized.contains(keyword)) {
        // Longer phrases are stronger signals than single words.
        score += keyword.contains(' ') ? 3 : 2;
      }
    }
    for (final word in faq.question.toLowerCase().split(
      RegExp(r'[^a-z0-9]+'),
    )) {
      if (word.length >= 4 && normalized.contains(word)) {
        score += 1;
      }
    }
    if (score > bestScore) {
      bestScore = score;
      best = faq;
    }
  }
  return bestScore >= 2 ? best : null;
}
