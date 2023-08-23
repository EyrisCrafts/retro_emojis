import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:emojis/emoji.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:get_it/get_it.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:quantity_input/quantity_input.dart';
import 'package:retro_typer/enums.dart';
import 'package:retro_typer/main.dart';
import 'package:retro_typer/models/model_emoji.dart';
import 'package:retro_typer/services/service_local_storage.dart';
import 'package:retro_typer/services/service_user_preferences.dart';
import 'package:scaffold_gradient_background/scaffold_gradient_background.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:http/http.dart' as http;

class WidgetSearch extends StatefulWidget {
  const WidgetSearch({super.key});

  @override
  State<WidgetSearch> createState() => _WidgetSearchState();
}

class _WidgetSearchState extends State<WidgetSearch> with WidgetsBindingObserver {
  int maxResultsAtOnce = 25;
  int inactiveTimes = 0;
  int selectedIndex = 0;

  double itemHeight = 116;
  double gridviewResidueHeight = 116;
  GlobalKey itemKey = GlobalKey();

  List<ModelEmoji> searchResults = [];
  List<ModelEmoji> allAsciiEmojis = [];
  List<ModelEmoji> allNormalEmojis = Emoji.all().map((e) => ModelEmoji(emoji: e.char, shortName: e.shortName, searchType: EnumSearchType.emojis)).toList();
  List<ModelEmoji> previouslyUsedEmojis = [];

  FocusNode focusNode = FocusNode();
  ScrollController scrollController = ScrollController();

  String searchText = "";

  ValueNotifier<EnumSearchType> searchType = ValueNotifier(EnumSearchType.ascii);
  final ValueNotifier<bool> _gridUpdate = ValueNotifier(false);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      inactiveTimes++;
    }
    if (state.name == "inactive" && inactiveTimes > 1) {
      log("Lost focus. Closing");
      // exit(0);
    }
  }

  Timer? timer;
  int millsecondsSoFar = 0;
  bool hasFirstSearchHappened = false;
  final ValueNotifier<bool> _isInSettings = ValueNotifier(false);
  int gridCrossAxisCount = 5;

  List<EnumSearchType> enabledSearchTypes = [];

  @override
  void initState() {
    super.initState();

    gridCrossAxisCount = GetIt.I<ServiceUserPreferences>().gridCrossAxisCount;
    maxResultsAtOnce = GetIt.I<ServiceUserPreferences>().maxMemesLoad;
    enabledSearchTypes = GetIt.I<ServiceUserPreferences>().enabledTypes;
    searchType.value = enabledSearchTypes.first;
    log("init state enabled search types: $enabledSearchTypes");

    log("Linit state");
    WidgetsBinding.instance.addObserver(this);
    ServicesBinding.instance.keyboard.addHandler(_onKey);

    loadEmojis();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      focusNode.requestFocus();
    });

    GetIt.I<ServiceLocalStorage>().getEmojis().then((value) {
      previouslyUsedEmojis = value;
      searchResults = previouslyUsedEmojis.toList();
      if (value.isNotEmpty) {
        _gridUpdate.value = !_gridUpdate.value;
        updateWindowSizeForImages();
      }
    });
  }

  void startTimer() {
    if (timer != null && timer!.isActive) {
      timer?.cancel();
    }
    timer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      millsecondsSoFar += 400;
      if (millsecondsSoFar > 1300 && searchType.value == EnumSearchType.image && searchText.isNotEmpty) {
        millsecondsSoFar = 0;
        timer.cancel();
        findMeme();
      }

      if (millsecondsSoFar > 1300 && searchType.value == EnumSearchType.gif && searchText.isNotEmpty) {
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
    allAsciiEmojis = (jsonData["retro_emojis"] as List).map((e) => ModelEmoji(searchType: EnumSearchType.ascii, emoji: e["phrase"], shortName: e["shortcut"])).toList();
  }

  void saveToLocal(ModelEmoji emoji) {
    if (!previouslyUsedEmojis.contains(emoji)) {
      previouslyUsedEmojis.insert(0, emoji);
      GetIt.I<ServiceLocalStorage>().saveEmojis(previouslyUsedEmojis);
    } else {
      final index = previouslyUsedEmojis.indexOf(emoji);
      previouslyUsedEmojis.removeAt(index);
      previouslyUsedEmojis.insert(0, emoji);
      GetIt.I<ServiceLocalStorage>().saveEmojis(previouslyUsedEmojis);
    }
  }

  void saveToClipboard() async {
    saveToLocal(searchResults[selectedIndex]);
    // EnumSearchType enumToLookFor = searchType.value;
    // if (searchText.isEmpty) {
    //   enumToLookFor = searchResults[selectedIndex].searchType;
    // }
    try {
      switch (searchResults[selectedIndex].searchType) {
        case EnumSearchType.ascii:
        case EnumSearchType.emojis:
          final emoji = searchResults[selectedIndex];
          await Clipboard.setData(ClipboardData(text: emoji.emoji));

        case EnumSearchType.gif:
        case EnumSearchType.image:
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
    log("Key pressed: $key ${enabledSearchTypes.toString()}");
    if (event is KeyDownEvent) {
      if (key == "Enter") {
        // Save to clipboard
        saveToClipboard();
      } else if (key == "Arrow Down") {
        updateItemHeight();
        updateSelectedIndex(EnumArrow.down);
      } else if (key == "Arrow Up") {
        updateItemHeight();
        updateSelectedIndex(EnumArrow.up);
      } else if (key == "Arrow Left") {
        updateSelectedIndex(EnumArrow.left);
      } else if (key == "Arrow Right") {
        updateSelectedIndex(EnumArrow.right);
      } else if (key == "Escape") {
        exit(0);
      } else if (key == (enabledSearchTypes.indexOf(EnumSearchType.ascii) + 1).toString()) {
        searchResults.clear();
        selectedIndex = 0;
        searchType.value = EnumSearchType.ascii;
        if (searchText.isNotEmpty) {
          findAsciiEmoji();
        }
      } else if (key == (enabledSearchTypes.indexOf(EnumSearchType.image) + 1).toString()) {
        selectedIndex = 0;
        searchResults.clear();
        searchType.value = EnumSearchType.image;
        if (searchText.isNotEmpty) {
          findMeme();
        }
      } else if (key == (enabledSearchTypes.indexOf(EnumSearchType.gif) + 1).toString()) {
        selectedIndex = 0;
        searchResults.clear();
        searchType.value = EnumSearchType.gif;
        if (searchText.isNotEmpty) {
          findGif();
        }
      } else if (key == (enabledSearchTypes.indexOf(EnumSearchType.emojis) + 1).toString()) {
        log("Pressed emojis");
        selectedIndex = 0;
        searchResults.clear();
        searchType.value = EnumSearchType.emojis;
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
    log("Updating window size");
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

    if (searchType.value == EnumSearchType.ascii) {
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
    final indexInViewport = ((selectedIndex ~/ gridCrossAxisCount) - itemsOutsideViewport);

    if (indexInViewport >= (gridCrossAxisCount - 1) && !goingUp) {
      final double newoffset = (((selectedIndex ~/ gridCrossAxisCount) - (gridCrossAxisCount - 2)) * itemHeight) + gridviewResidueHeight;
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
            searchResults.add(ModelEmoji(memeUrl: result["media"].first["mp4"]["preview"], searchType: EnumSearchType.image));
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
            searchResults.add(ModelEmoji(memeUrl: result["media"].first["mediumgif"]["url"], searchType: EnumSearchType.gif));
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

  void updateItemHeight() {
    final tmpHeight = (itemKey.currentContext?.findRenderObject()?.paintBounds.size.width ?? 0);
    if (tmpHeight != 0) {
      itemHeight = tmpHeight / gridCrossAxisCount;
      gridviewResidueHeight = tmpHeight % itemHeight;
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = !(MediaQuery.of(context).platformBrightness == Brightness.dark ? true : false);

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
        return ValueListenableBuilder(
            valueListenable: _isInSettings,
            builder: (context, isInSettings, __) {
              final filteredSearchTypes = enabledSearchTypes;
              log("Filtered search types: $filteredSearchTypes");
              return Padding(
                padding: const EdgeInsets.only(left: 10, right: 10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            enabled: !isInSettings,
                            decoration:
                                InputDecoration(hintStyle: TextStyle(color: isDarkMode ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.5)), hintText: "Search", border: InputBorder.none),
                            focusNode: focusNode,
                            cursorColor: isDarkMode ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.5),
                            style: TextStyle(color: isDarkMode ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.9)),
                            inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r"\d"))],
                            onChanged: (value) {
                              hasFirstSearchHappened = true;
                              searchText = value;
                              selectedIndex = 0;
                              scrollController.jumpTo(0);
                              if (searchText.isEmpty) {
                                searchResults = previouslyUsedEmojis.toList();
                                _gridUpdate.value = !_gridUpdate.value;
                                return;
                              }
                              if (searchType.value == EnumSearchType.image) {
                                startTimer();
                              } else if (searchType.value == EnumSearchType.gif) {
                                startTimer();
                              } else if (searchType.value == EnumSearchType.ascii) {
                                findAsciiEmoji();
                              } else if (searchType.value == EnumSearchType.emojis) {
                                findEmoji();
                              }
                            },
                          ),
                        ),
                        IconButton(
                          icon: ValueListenableBuilder(
                              valueListenable: _isInSettings,
                              builder: (context, isInSettings, _) {
                                return Icon(isInSettings ? Icons.clear : Icons.settings);
                              }),
                          onPressed: () {
                            log("Pressed settings");
                            _isInSettings.value = !_isInSettings.value;
                            Future.delayed(const Duration(milliseconds: 100), () {
                              if (!_isInSettings.value) {
                                updateItemHeight();

                                focusNode.requestFocus();

                                log("Item height is $itemHeight");
                              }
                            });
                            updateWindowSizeForImages();
                          },
                        ),
                      ],
                    ),
                    if (!isInSettings)
                      Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          for (int i = 0; i < filteredSearchTypes.length; i++)
                            ValueListenableBuilder(
                              valueListenable: searchType,
                              builder: (context,searchTypes,_) {
                                return WidgetSearchTypeButton(
                                  isActive: searchTypes == filteredSearchTypes[i],
                                  isDarkMode: isDarkMode,
                                  shortcut: "(${i + 1})",
                                  name: "  ${filteredSearchTypes[i].name}",
                                  onTap: () {
                                    if (filteredSearchTypes[i] == EnumSearchType.ascii) {
                                      searchResults.clear();
                                      selectedIndex = 0;
                                      searchType.value = EnumSearchType.ascii;
                                      if (searchText.isNotEmpty) {
                                        findAsciiEmoji();
                                      }
                                    } else if (filteredSearchTypes[i] == EnumSearchType.image) {
                                      selectedIndex = 0;
                                      searchResults.clear();
                                      searchType.value = EnumSearchType.image;
                                      if (searchText.isNotEmpty) {
                                        findMeme();
                                      }
                                    } else if (filteredSearchTypes[i] == EnumSearchType.gif) {
                                      selectedIndex = 0;
                                      searchResults.clear();
                                      searchType.value = EnumSearchType.gif;
                                      if (searchText.isNotEmpty) {
                                        findGif();
                                      }
                                    } else if (filteredSearchTypes[i] == EnumSearchType.emojis) {
                                      selectedIndex = 0;
                                      searchResults.clear();
                                      searchType.value = EnumSearchType.emojis;
                                      if (searchText.isNotEmpty) {
                                        findEmoji();
                                      }
                                    }
                                  },
                                );
                              }
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
                    if (isInSettings)
                      Column(
                        children: [
                          ListTile(
                              title: Text("Grid cross count", style: TextStyle(color: Colors.white.withOpacity(0.5))),
                              trailing: ValueListenableBuilder<bool>(
                                  valueListenable: _gridUpdate,
                                  builder: (context, _, __) {
                                    return QuantityInput(
                                      maxValue: 10,
                                      minValue: 3,
                                      buttonColor: Colors.white.withOpacity(0.5),
                                      value: gridCrossAxisCount,
                                      onChanged: (value) {
                                        gridCrossAxisCount = int.tryParse(value) ?? 5;
                                        // Save to shared preferences
                                        GetIt.I<ServiceLocalStorage>().saveGridCrossAxisCount(gridCrossAxisCount);
                                        _gridUpdate.value = !_gridUpdate.value;
                                      },
                                    );
                                  })),
                          ListTile(
                              title: Text("Max memes", style: TextStyle(color: Colors.white.withOpacity(0.5))),
                              trailing: ValueListenableBuilder<bool>(
                                  valueListenable: _gridUpdate,
                                  builder: (context, __, _) {
                                    return QuantityInput(
                                      maxValue: 50,
                                      buttonColor: Colors.white.withOpacity(0.5),
                                      minValue: 3,
                                      value: maxResultsAtOnce,
                                      onChanged: (value) {
                                        maxResultsAtOnce = int.tryParse(value) ?? 5;
                                        // Save to shared preferences
                                        GetIt.I<ServiceLocalStorage>().saveMaxMemesLoad(maxResultsAtOnce);
                                        _gridUpdate.value = !_gridUpdate.value;
                                      },
                                    );
                                  })),
                          for (EnumSearchType type in EnumSearchType.values)
                            ValueListenableBuilder<bool>(
                                valueListenable: _gridUpdate,
                                builder: (context, _, __) {
                                  return SwitchListTile(
                                    title: Text(type.name, style: TextStyle(color: Colors.white.withOpacity(0.5))),
                                    value: enabledSearchTypes.contains(type),
                                    onChanged: (value) {
                                      if (value) {
                                        enabledSearchTypes.add(type);
                                      } else {
                                        if (enabledSearchTypes.length == 1) {
                                          return;
                                        }
                                        enabledSearchTypes.remove(type);
                                      }
                                      GetIt.I<ServiceUserPreferences>().enabledTypes = enabledSearchTypes;
                                      // Save to shared preferences
                                      GetIt.I<ServiceLocalStorage>().saveEnabledTypes(enabledSearchTypes.map((e) => e.name).toList());
                                      _gridUpdate.value = !_gridUpdate.value;
                                    },
                                  );
                                }),
                          ElevatedButton(
                              onPressed: () {
                                previouslyUsedEmojis.clear();
                                searchResults.clear();
                                GetIt.I<ServiceLocalStorage>().saveEmojis(previouslyUsedEmojis);
                              },
                              child: Text("Clear used emojis", style: TextStyle(color: Colors.black))),
                        ],
                      ),
                    if (!isInSettings)
                      Expanded(
                          child: ValueListenableBuilder<EnumSearchType>(
                              valueListenable: searchType,
                              builder: (context, EnumSearchType value, child) {
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
                                          key: itemKey,
                                          controller: scrollController,
                                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: gridCrossAxisCount, childAspectRatio: 1),
                                          children: List.generate(searchResults.length, (index) {
                                            final item = searchResults[index];

                                            Widget child;
                                            if (item.searchType == EnumSearchType.ascii || item.searchType == EnumSearchType.emojis) {
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
                                                              color: isDarkMode ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.7),
                                                              fontSize: searchResults[index].searchType == EnumSearchType.emojis ? 30 : 16)),
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

                                            return GestureDetector(
                                              onTap: () {
                                                saveToClipboard();
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.all(5),
                                                decoration: selectedIndex == index
                                                    ? BoxDecoration(
                                                        color: (item.searchType == EnumSearchType.image || item.searchType == EnumSearchType.gif)
                                                            ? Colors.white.withOpacity(0.6)
                                                            : Colors.blue.withOpacity(0.2),
                                                        borderRadius: BorderRadius.circular(10),
                                                      )
                                                    : null,
                                                child: child,
                                              ),
                                            );
                                          }));
                                    });
                              }))
                  ],
                ),
              );
            });
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
    required this.onTap,
    required this.isActive,
  });

  final bool isDarkMode;
  final String shortcut;
  final String name;
  final Function() onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            Text(shortcut, style: TextStyle(color: isActive ? Colors.black :  Colors.grey.withOpacity(0.5))),
            Text(name, style: TextStyle(color: isDarkMode ? Colors.white.withOpacity(isActive ? 1 : 0.5) : Colors.black.withOpacity( isActive ? 1 : 0.7))),
          ],
        ),
      ),
    );
  }
}
