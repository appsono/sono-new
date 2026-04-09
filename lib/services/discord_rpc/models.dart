/// Discord RPC data models
///
/// Ported from https://github.com/brahmkshatriya/echo-discord (PreMid headless method)

class DiscordActivity {
  final String? applicationId;
  final String? name;
  final String? platform;
  final int? type;
  final int? statusDisplayType;
  final String? details;
  final String? state;
  final DiscordAssets? assets;
  final DiscordTimestamps? timestamps;
  final List<DiscordButton>? buttons;

  const DiscordActivity({
    this.applicationId,
    this.name,
    this.platform,
    this.type,
    this.statusDisplayType,
    this.details,
    this.state,
    this.assets,
    this.timestamps,
    this.buttons,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (applicationId != null) map['application_id'] = applicationId;
    if (name != null) map['name'] = name;
    if (platform != null) map['platform'] = platform;
    if (type != null) map['type'] = type;
    if (statusDisplayType != null) map['statusDisplayType'] = statusDisplayType;
    if (details != null) map['details'] = details;
    if (state != null) map['state'] = state;
    if (assets != null) map['assets'] = assets!.toJson();
    if (timestamps != null) map['timestamps'] = timestamps!.toJson();
    if (buttons != null) {
      map['buttons'] = buttons!.map((b) => b.toJson()).toList();
    }
    return map;
  }
}

class DiscordAssets {
  final String? largeText;
  final String? largeImage;
  final String? largeUrl;
  final String? smallText;
  final String? smallImage;
  final String? smallUrl;

  const DiscordAssets({
    this.largeText,
    this.largeImage,
    this.largeUrl,
    this.smallText,
    this.smallImage,
    this.smallUrl,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (largeText != null) map['large_text'] = largeText;
    if (largeImage != null) map['large_image'] = largeImage;
    if (largeUrl != null) map['large_url'] = largeUrl;
    if (smallText != null) map['small_text'] = smallText;
    if (smallImage != null) map['small_image'] = smallImage;
    if (smallUrl != null) map['small_url'] = smallUrl;
    return map;
  }
}

class DiscordButton {
  final String label;
  final String url;

  const DiscordButton({required this.label, required this.url});

  Map<String, dynamic> toJson() => {'label': label, 'url': url};
}

class DiscordTimestamps {
  final int? start;
  final int? end;

  const DiscordTimestamps({this.start, this.end});

  Map<String, dynamic> toJson() => {
    if (start != null) 'start': start,
    if (end != null) 'end': end,
  };
}

class DiscordSession {
  final List<DiscordActivity>? activities;
  final String? token;

  const DiscordSession({this.activities, this.token});

  Map<String, dynamic> toJson() => {
    if (activities != null)
      'activities': activities!.map((a) => a.toJson()).toList(),
    if (token != null) 'token': token,
  };
}

// ignore_for_file: dangling_library_doc_comments
