import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:scaffold_gradient_background/scaffold_gradient_background.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'main.dart';
import 'models/model_retro_emoji.dart';

// TODO Features needed
// Auto close when application loses focus
// Add normal emojis
// Add Gifs !
// Add ascii texts images or something
// Recently used appear at the top

class WidgetSearch extends StatefulWidget {
  const WidgetSearch({super.key});

  @override
  State<WidgetSearch> createState() => _WidgetSearchState();
}

class _WidgetSearchState extends State<WidgetSearch> with WidgetsBindingObserver {
  static const maxResultsAtOnce = 7;
  static const double searchItemHeight = 40;

  List<ModelRetroEmoji> searchResults = [];
  List<ModelRetroEmoji> allEmojis = [];
  int selectedIndex = 0;
  FocusNode focusNode = FocusNode();
  ScrollController scrollController = ScrollController();
  int inactiveTimes = 0;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    log("AppLifecycleState: $state");
    if (state == AppLifecycleState.inactive) {
      inactiveTimes++;
    }
    if (state.name == "inactive" && inactiveTimes > 1) {
      log("Lost focus. Closing");
      exit(0);
    }
  }

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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void loadEmojis() async {
    // Load json file from assets folder
    final jsonString = await rootBundle.loadString("assets/emojis.json");

    // Parse the loaded string as JSON
    final jsonData = jsonDecode(jsonString);
    allEmojis = (jsonData["retro_emojis"] as List).map((e) => ModelRetroEmoji.fromMap(e)).toList();
  }

  void saveToClipboard() async {
    try {
      final emoji = searchResults[selectedIndex];
      await Clipboard.setData(ClipboardData(text: emoji.emoji));
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
        updateSelectedIndex(1);
        adjustScroll(false);
      } else if (key == "Arrow Up") {
        updateSelectedIndex(-1);
        adjustScroll(true);
      } else if (key == "ArrowLeft") {
      } else if (key == "ArrowRight") {
      } else if (key == "Escape") {
        exit(0); // TODO Apple may suspend the application because it looks like it crashed, add animation to avoid it
      }
    }

    if (event.character != null) {
      //escape key is 27
      final int code = event.character!.codeUnitAt(0);

      if (code == 27) {
        exit(0); // TODO Apple may suspend the application because it looks like it crashed, add animation to avoid it
      }
    }

    return false;
  }

  // Adjust scroll position if at the edge and the user presses up/down
  void adjustScroll(bool goingUp) {
    if (searchResults.length <= maxResultsAtOnce) {
      return;
    }
    final scrollOffset = scrollController.offset;
    // selected Item index in viewport
    final itemsOutsideViewport = (scrollOffset / searchItemHeight).floor();
    final indexInViewport = (selectedIndex - itemsOutsideViewport);

    if (indexInViewport == 6 && !goingUp) {
      scrollController.animateTo((selectedIndex - 5) * searchItemHeight, duration: const Duration(milliseconds: 100), curve: Curves.easeIn);
    } else if (indexInViewport == 1 && goingUp) {
      scrollController.animateTo(scrollOffset - searchItemHeight, duration: const Duration(milliseconds: 100), curve: Curves.easeIn);
    }
  }

  // Default height is 70
  void updateWindowSize() {
    final double calculatedHeight = searchBarSize + 3 + 5 + ((searchResults.length <= maxResultsAtOnce ? searchResults.length : maxResultsAtOnce) * 40);

    windowManager.setSize(Size(600, calculatedHeight));
  }

  void updateSelectedIndex(int delta) {
    if (delta == -1) {
      if (selectedIndex == 0) {
        // selectedIndex = searchResults.length - 1;
      } else {
        selectedIndex--;
      }
    } else if (delta == 1) {
      if (selectedIndex == searchResults.length - 1) {
        // selectedIndex = 0;
      } else {
        selectedIndex++;
      }
    } else {
      selectedIndex = 0;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = MediaQuery.of(context).platformBrightness == Brightness.dark ? true : false;
    // isDarkMode = !isDarkMode;
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
                onChanged: (value) {
                  setState(() {
                    searchResults = allEmojis.where((element) => element.shortName.toLowerCase().contains(value.toLowerCase())).toList();

                    updateWindowSize();
                    updateSelectedIndex(0);
                  });
                },
              ),
              if (searchResults.isNotEmpty)
                Container(
                  height: 1,
                  margin: const EdgeInsets.only(bottom: 2),
                  width: double.maxFinite,
                  color: Colors.grey.withOpacity(0.5),
                ),
              Expanded(
                  child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.only(bottom: 5),
                      itemBuilder: (context, index) {
                        return SizedBox(
                          height: searchItemHeight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            decoration: BoxDecoration(color: selectedIndex == index ? Colors.blue.withOpacity(0.4) : Colors.transparent, borderRadius: BorderRadius.circular(5)),
                            child: Row(
                              children: [
                                Text(
                                  searchResults[index].shortName,
                                  style: TextStyle(color: isDarkMode ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.7)),
                                ),
                                const Spacer(),
                                Text(searchResults[index].emoji, style: TextStyle(color: isDarkMode ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.7))),
                              ],
                            ),
                          ),
                        );
                      },
                      itemCount: searchResults.length))
            ],
          ),
        );
      }),
    );
  }
}
