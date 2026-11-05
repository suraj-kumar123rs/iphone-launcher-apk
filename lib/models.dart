class AppInfo {
  final String pkg;
  final String label;
  final String icon; // cached PNG path
  final int category; // Android ApplicationInfo.category, -1 if unknown
  final int installed;
  final bool system;

  AppInfo.fromMap(Map m)
      : pkg = '${m['pkg']}',
        label = '${m['label']}',
        icon = '${m['icon']}',
        category = (m['category'] as num?)?.toInt() ?? -1,
        installed = (m['installed'] as num?)?.toInt() ?? 0,
        system = m['system'] == true;

  Map<String, Object?> toMap() => {
        'pkg': pkg,
        'label': label,
        'icon': icon,
        'category': category,
        'installed': installed,
        'system': system,
      };
}

/// One slot on the home screen or dock: either an app or a folder of apps.
class HomeItem {
  final String id;
  final String? pkg;
  String name;
  final List<String> apps;

  HomeItem.app(String p)
      : id = 'a:$p',
        pkg = p,
        name = '',
        apps = [];

  HomeItem.folder(this.name, List<String> pkgs)
      : id = 'f:${DateTime.now().microsecondsSinceEpoch}',
        pkg = null,
        apps = List.of(pkgs);

  HomeItem._(this.id, this.pkg, this.name, this.apps);

  bool get isFolder => pkg == null;

  Map<String, Object?> toJson() => {'id': id, 'pkg': pkg, 'name': name, 'apps': apps};

  factory HomeItem.fromJson(Map j) => HomeItem._(
        '${j['id']}',
        j['pkg'] as String?,
        '${j['name'] ?? ''}',
        List<String>.from((j['apps'] as List?) ?? const []),
      );
}

class LibraryGroup {
  final String name;
  final List<AppInfo> apps;
  const LibraryGroup(this.name, this.apps);
}

const _androidCategories = {
  0: 'Games',
  1: 'Music & Audio',
  2: 'Entertainment',
  3: 'Photo & Video',
  4: 'Social',
  5: 'News & Reading',
  6: 'Travel',
  7: 'Productivity',
  8: 'Utilities',
};

const _keywords = <String, List<String>>{
  'Social': ['whatsapp', 'instagram', 'facebook', 'telegram', 'snapchat', 'twitter', 'threads', 'linkedin', 'discord', 'messenger', 'sharechat', 'signal', 'reddit', 'truecaller'],
  'Finance': ['paytm', 'phonepe', 'bank', 'upi', 'wallet', 'zerodha', 'groww', 'money', 'bhim', 'credit', 'nbu.paisa', 'gpay', 'kite'],
  'Shopping & Food': ['amazon', 'flipkart', 'myntra', 'meesho', 'shop', 'ajio', 'nykaa', 'blinkit', 'zepto', 'swiggy', 'zomato', 'bigbasket', 'jiomart'],
  'Entertainment': ['youtube', 'netflix', 'hotstar', 'primevideo', 'video', 'jiocinema', 'zee5', 'sonyliv', 'mxplayer'],
  'Music & Audio': ['music', 'spotify', 'saavn', 'gaana', 'wynk', 'audio', 'podcast', 'tunora', 'radio'],
  'Photo & Video': ['camera', 'photo', 'gallery', 'snapseed', 'lightroom', 'picsart', 'capcut', 'editor'],
  'Travel': ['maps', 'uber', 'olacabs', 'rapido', 'irctc', 'travel', 'makemytrip', 'redbus', 'goibibo', 'indigo'],
  'Education': ['learn', 'byju', 'unacademy', 'duolingo', 'coursera', 'udemy', 'study', 'classroom', 'iitm'],
  'Productivity': ['docs', 'sheets', 'slides', 'drive', 'office', 'word', 'excel', 'notes', 'keep', 'calendar', 'gmail', 'mail', 'outlook', 'notion', 'todo', 'tasks', 'zoom', 'meet', 'teams', 'pdf', 'scanner', 'claude', 'chatgpt', 'gemini'],
  'Utilities': ['settings', 'clock', 'calculator', 'files', 'contacts', 'dialer', 'phone', 'messag', 'recorder', 'weather', 'vending', 'security', 'cleaner', 'android'],
};

String categoryOf(AppInfo a) {
  if (a.category == 0) return 'Games';
  final s = '${a.label} ${a.pkg}'.toLowerCase();
  for (final e in _keywords.entries) {
    for (final k in e.value) {
      if (s.contains(k)) return e.key;
    }
  }
  final c = _androidCategories[a.category];
  if (c != null) return c;
  return a.system ? 'Utilities' : 'Other';
}
