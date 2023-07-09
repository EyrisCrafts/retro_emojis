import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:emojis/emoji.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:retro_typer/enums.dart';
import 'package:retro_typer/main.dart';
import 'package:retro_typer/models/model_emoji.dart';
import 'package:scaffold_gradient_background/scaffold_gradient_background.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:http/http.dart' as http;

// TODO Features needed
// Add ascii texts images or something
// Recently used appear at the top

class WidgetSearch extends StatefulWidget {
  const WidgetSearch({super.key});

  @override
  State<WidgetSearch> createState() => _WidgetSearchState();
}

class _WidgetSearchState extends State<WidgetSearch> with WidgetsBindingObserver {
  static const maxResultsAtOnce = 25;

  List<ModelEmoji> searchResults = [];
  List<ModelEmoji> allAsciiEmojis = [];
  List<ModelEmoji> allNormalEmojis = Emoji.all().map((e) => ModelEmoji(emoji: e.char, shortName: e.shortName, searchType: SearchType.emojis)).toList();

  int selectedIndex = 0;
  FocusNode focusNode = FocusNode();
  ScrollController scrollController = ScrollController();
  int inactiveTimes = 0;

  String searchText = "";

  ValueNotifier<SearchType> searchType = ValueNotifier(SearchType.ascii);
  final ValueNotifier<bool> _gridUpdate = ValueNotifier(false);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      inactiveTimes++;
    }
    if (state.name == "inactive" && inactiveTimes > 1) {
      log("Lost focus. Closing");

      exit(0);
    }
  }

  Timer? timer;
  int millsecondsSoFar = 0;
  bool hasFirstSearchHappened = false;

  @override
  void initState() {
    super.initState();

    log("Linit state");
    WidgetsBinding.instance.addObserver(this);
    ServicesBinding.instance.keyboard.addHandler(_onKey);

    loadEmojis();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      focusNode.requestFocus();
    });
  }

  void startTimer() {
    if (timer != null && timer!.isActive) {
      timer?.cancel();
    }
    timer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      millsecondsSoFar += 400;
      log("Timer: $millsecondsSoFar $searchText ${searchType.value}");
      if (millsecondsSoFar > 1300 && searchType.value == SearchType.image && searchText.isNotEmpty) {
        millsecondsSoFar = 0;
        timer.cancel();
        findMeme();
      }

      if (millsecondsSoFar > 1300 && searchType.value == SearchType.gif && searchText.isNotEmpty) {
        millsecondsSoFar = 0;
        timer.cancel();
        findGif();
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void loadEmojis() async {
    // Load json file from assets folder
    final jsonString = await rootBundle.loadString("assets/emojis.json");

    // Parse the loaded string as JSON
    final jsonData = jsonDecode(jsonString);
    allAsciiEmojis = (jsonData["retro_emojis"] as List).map((e) => ModelEmoji(searchType: SearchType.ascii, emoji: e["phrase"], shortName: e["shortcut"])).toList();

    // Load emojis
  }

  void saveToClipboard() async {
    try {
      switch (searchType.value) {
        case SearchType.ascii:
        case SearchType.emojis:
          final emoji = searchResults[selectedIndex];
          await Clipboard.setData(ClipboardData(text: emoji.emoji));
        case SearchType.gif:
        case SearchType.image:
          final memeUrl = searchResults[selectedIndex].memeUrl;
          // Check if available in cache
          var file = await DefaultCacheManager().getSingleFile(memeUrl);
          if (await file.exists()) {
            await Pasteboard.writeFiles([file.path]);
          } else {
            log("File not found in cache");
          }
      }
    } catch (e) {
      log("Error saving to clipboard: $e");
    }
    exit(0);
  }

  bool _onKey(KeyEvent event) {
    final key = event.logicalKey.keyLabel;

    if (event is KeyDownEvent) {
      if (key == "Enter") {
        // Save to clipboard
        saveToClipboard();
      } else if (key == "Arrow Down") {
        updateSelectedIndex(EnumArrow.down);
      } else if (key == "Arrow Up") {
        updateSelectedIndex(EnumArrow.up);
      } else if (key == "Arrow Left") {
        updateSelectedIndex(EnumArrow.left);
      } else if (key == "Arrow Right") {
        updateSelectedIndex(EnumArrow.right);
      } else if (key == "Escape") {
        exit(0);
      } else if (key == "1") {
        searchResults.clear();
        selectedIndex = 0;
        searchType.value = SearchType.ascii;
        if (searchText.isNotEmpty) {
          findAsciiEmoji();
        }
      } else if (key == "2") {
        selectedIndex = 0;
        searchResults.clear();
        searchType.value = SearchType.image;
        if (searchText.isNotEmpty) {
          findMeme();
        }
      } else if (key == "3") {
        selectedIndex = 0;
        searchResults.clear();
        searchType.value = SearchType.gif;
        if (searchText.isNotEmpty) {
          findGif();
        }
      } else if (key == "4") {
        selectedIndex = 0;
        searchResults.clear();
        searchType.value = SearchType.emojis;
        if (searchText.isNotEmpty) {
          findEmoji();
        }
      }
    }

    if (event.character != null) {
      //escape key is 27
      final int code = event.character!.codeUnitAt(0);

      if (code == 27) {
        exit(0);
      }
    }

    return false;
  }

  void updateWindowSizeForImages() {
    windowManager.setSize(const Size(600, searchBarSize + 464));
  }

  void updateSelectedIndex(EnumArrow arrow) {
    int delta = 0;
    switch (arrow) {
      case EnumArrow.up:
        delta = selectedIndex - gridCrossAxisCount;
        break;
      case EnumArrow.down:
        delta = selectedIndex + gridCrossAxisCount;
        break;
      case EnumArrow.left:
        delta = selectedIndex - 1;
        break;
      case EnumArrow.right:
        delta = selectedIndex + 1;
        break;
    }
    int length = searchResults.length;

    if (searchType.value == SearchType.ascii) {
      if (delta < length && delta >= 0) {
        selectedIndex = delta;
        _gridUpdate.value = !_gridUpdate.value;
      }
    } else {
      if (delta < length && delta >= 0) {
        selectedIndex = delta;
        _gridUpdate.value = !_gridUpdate.value;
      }
    }
    if (arrow == EnumArrow.up || arrow == EnumArrow.down) {
      adjustScroll(arrow == EnumArrow.up);
    }
  }

  void adjustScroll(bool goingUp) {
    final scrollOffset = scrollController.offset;
    // selected Item index in viewport
    final itemsOutsideViewport = (scrollOffset / itemHeight).floor();
    final indexInViewport = ((selectedIndex ~/ 5) - itemsOutsideViewport);

    if (indexInViewport >= 4 && !goingUp) {
      final double newoffset = ((selectedIndex ~/ 5) - 3) * itemHeight;
      scrollController.animateTo(newoffset, duration: const Duration(milliseconds: 100), curve: Curves.easeIn);
    } else if (indexInViewport == 0 && goingUp) {
      scrollController.animateTo(scrollOffset - itemHeight, duration: const Duration(milliseconds: 100), curve: Curves.easeIn);
    }
  }

  void findMeme() {
    searchResults.clear();
    log("Searching for memes with $searchText");
    final url = "https://g.tenor.com/v1/search?q=$searchText&key=LIVDSRZULELA&limit=$maxResultsAtOnce";
    try {
      http.get(Uri.parse(url)).then((response) {
        final json = jsonDecode(response.body);
        final data = json["results"] as List<dynamic>;
        for (final result in data) {
          try {
            searchResults.add(ModelEmoji(memeUrl: result["media"].first["mp4"]["preview"], searchType: SearchType.image));
          } catch (e) {
            log("Error parsing meme: $e");
          }
        }
        updateWindowSizeForImages();
        _gridUpdate.value = !_gridUpdate.value;
      });
    } catch (e) {
      log("Error searching for memes: $e");
    }
  }

  void findGif() {
    searchResults.clear();
    log("Searching for memes with $searchText");
    final url = "https://g.tenor.com/v1/search?q=$searchText&key=LIVDSRZULELA&limit=$maxResultsAtOnce";
    try {
      http.get(Uri.parse(url)).then((response) {
        final json = jsonDecode(response.body);
        final data = json["results"] as List<dynamic>;
        for (final result in data) {
          try {
            searchResults.add(ModelEmoji(memeUrl: result["media"].first["mediumgif"]["url"], searchType: SearchType.gif));
          } catch (e) {
            log("Error parsing meme: $e");
          }
        }
        log("Memes length ${searchResults.length}");
        updateWindowSizeForImages();
        _gridUpdate.value = !_gridUpdate.value;
      });
    } catch (e) {
      log("Error searching for memes: $e");
    }
  }

  void findAsciiEmoji() {
    searchResults = allAsciiEmojis.where((element) => element.shortName.toLowerCase().contains(searchText.toLowerCase())).toList();
    _gridUpdate.value = !_gridUpdate.value;
    updateWindowSizeForImages();
  }

  void findEmoji() {
    searchResults = allNormalEmojis.where((element) => element.shortName.toLowerCase().contains(searchText.toLowerCase())).toList();
    _gridUpdate.value = !_gridUpdate.value;
    updateWindowSizeForImages();
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = MediaQuery.of(context).platformBrightness == Brightness.dark ? true : false;

    return ScaffoldGradientBackground(
      gradient: LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [
          isDarkMode ? const Color.fromARGB(255, 64, 89, 114) : const Color(0xFF8EC5FC),
          isDarkMode ? const Color.fromARGB(255, 108, 93, 121) : const Color(0xFFE0C3FC),
        ],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        return Padding(
          padding: const EdgeInsets.only(left: 10, right: 10),
          child: Column(
            children: [
              TextFormField(
                decoration: InputDecoration(hintStyle: TextStyle(color: isDarkMode ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.5)), hintText: "Search", border: InputBorder.none),
                focusNode: focusNode,
                cursorColor: isDarkMode ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.5),
                style: TextStyle(color: isDarkMode ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.9)),
                inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r"\d"))],
                onChanged: (value) {
                  hasFirstSearchHappened = true;
                  searchText = value;
                  if (searchType.value == SearchType.image) {
                    startTimer();
                  } else if (searchType.value == SearchType.gif) {
                    startTimer();
                  } else if (searchType.value == SearchType.ascii) {
                    findAsciiEmoji();
                  } else if (searchType.value == SearchType.emojis) {
                    findEmoji();
                  }
                },
              ),
              Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  WidgetSearchTypeButton(
                    isDarkMode: isDarkMode,
                    shortcut: "(1)",
                    name: "  Ascii",
                  ),
                  WidgetSearchTypeButton(
                    isDarkMode: isDarkMode,
                    shortcut: "(2)",
                    name: "  Images",
                  ),
                  WidgetSearchTypeButton(
                    isDarkMode: isDarkMode,
                    shortcut: "(3)",
                    name: "  Gifs",
                  ),
                  WidgetSearchTypeButton(
                    isDarkMode: isDarkMode,
                    shortcut: "(4)",
                    name: "  Emojis",
                  ),
                ],
              ),
              if (searchResults.isNotEmpty)
                Container(
                  height: 1,
                  margin: const EdgeInsets.only(bottom: 2),
                  width: double.maxFinite,
                  color: Colors.grey.withOpacity(0.5),
                ),
              Expanded(
                  child: ValueListenableBuilder(
                      valueListenable: searchType,
                      builder: (context, SearchType value, child) {
                        return ValueListenableBuilder(
                            valueListenable: _gridUpdate,
                            builder: (context, _, __) {
                              if (searchResults.isEmpty && hasFirstSearchHappened) {
                                return Center(
                                  child: Text(
                                    "Search : )",
                                    style: TextStyle(color: isDarkMode ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.5)),
                                  ),
                                );
                              }
                              return GridView(
                                  controller: scrollController,
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: gridCrossAxisCount, childAspectRatio: 1),
                                  children: List.generate(searchResults.length, (index) {
                                    final item = searchResults[index];
                                    Widget child;
                                    if (item.searchType == SearchType.ascii || item.searchType == SearchType.emojis) {
                                      String shortName = searchResults[index].shortName.replaceAll("_", " ");
                                      String emoji = searchResults[index].emoji;
                                      child = Container(
                                        alignment: Alignment.center,
                                        child: Column(
                                          children: [
                                            Flexible(
                                              flex: 2,
                                              fit: FlexFit.tight,
                                              child: Container(
                                                alignment: Alignment.center,
                                                width: double.maxFinite,
                                                child: AutoSizeText(
                                                  shortName,
                                                  textAlign: TextAlign.center,
                                                  maxLines: 2,
                                                  style: TextStyle(color: isDarkMode ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.7)),
                                                ),
                                              ),
                                            ),
                                            Flexible(
                                              flex: 3,
                                              fit: FlexFit.tight,
                                              child: Text(emoji,
                                                  style: TextStyle(
                                                      color: isDarkMode ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.7), fontSize: searchType.value == SearchType.emojis ? 30 : 12)),
                                            ),
                                          ],
                                        ),
                                      );
                                    } else {
                                      child = CachedNetworkImage(
                                        imageUrl: item.memeUrl,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                                        errorWidget: (context, url, error) => const Icon(Icons.error),
                                      );
                                    }

                                    return Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: selectedIndex == index
                                          ? BoxDecoration(
                                              color: (item.searchType == SearchType.image || item.searchType == SearchType.gif) ? Colors.white.withOpacity(0.6) : Colors.blue.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(10),
                                            )
                                          : null,
                                      child: child,
                                    );
                                  }));
                            });
                      }))
            ],
          ),
        );
      }),
    );
  }
}

class WidgetSearchTypeButton extends StatelessWidget {
  const WidgetSearchTypeButton({
    super.key,
    required this.isDarkMode,
    required this.shortcut,
    required this.name,
  });

  final bool isDarkMode;
  final String shortcut;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Text(shortcut, style: TextStyle(color: Colors.grey.withOpacity(0.5))),
          Text(name, style: TextStyle(color: isDarkMode ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.5))),
        ],
      ),
    );
  }
}
