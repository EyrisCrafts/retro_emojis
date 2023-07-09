import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:emojis/emoji.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:retro_typer/enums.dart';
import 'package:retro_typer/main.dart';
import 'package:retro_typer/models/model_retro_emoji.dart';
import 'package:retro_typer/models/model_visibility.dart';
import 'package:scaffold_gradient_background/scaffold_gradient_background.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:window_manager/window_manager.dart';
import 'package:http/http.dart' as http;

// TODO Features needed
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

  List<ModelRetroEmoji> searchResults = [];
  List<ModelRetroEmoji> allEmojis = [];
  List<ModelVisibilty> visibiltyList = [];
  List<String> memeResults = [];
  List<Emoji> emojis = Emoji.all();

  int selectedIndex = 0;
  int visibiltyIndex = 0;
  FocusNode focusNode = FocusNode();
  ScrollController scrollController = ScrollController();
  int inactiveTimes = 0;

  String searchText = "";

  ValueNotifier<SearchType> searchType = ValueNotifier(SearchType.ascii);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      inactiveTimes++;
    }
    if (state.name == "inactive" && inactiveTimes > 1) {
      log("Lost focus. Closing");
      // TODO uncomment this
      // exit(0);
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
    allEmojis = (jsonData["retro_emojis"] as List).map((e) => ModelRetroEmoji.fromMap(e)).toList();
  }

  void saveToClipboard() async {
    try {
      if (searchType.value == SearchType.ascii) {
        final emoji = searchResults[selectedIndex];
        await Clipboard.setData(ClipboardData(text: emoji.emoji));
      } else {
        // Get the url
        final memeUrl = memeResults[selectedIndex];
        // Check if available in cache
        var file = await DefaultCacheManager().getSingleFile(memeUrl);
        if (await file.exists()) {
          await Pasteboard.writeFiles([file.path]);
        } else {
          log("File not found in cache");
        }
        //TODO Download if not in cache
      }
    } catch (e) {
      log("Error saving to clipboard: $e");
    }
    exit(0);
  }

  void adjustVisibiltyindex(EnumArrow arrow) {
    switch (arrow) {
      case EnumArrow.up:
        if (visibiltyIndex <= 4) {
          return;
        }
        visibiltyIndex = visibiltyIndex - 5;
        break;
      case EnumArrow.down:
        if (visibiltyIndex >= 15) {
          return;
        }
        visibiltyIndex = visibiltyIndex + 5;
        break;
      case EnumArrow.left:
        if (visibiltyIndex == 4) {
          visibiltyIndex = 0;
          return;
        }
        visibiltyIndex--;
        break;
      case EnumArrow.right:
        if (visibiltyIndex == 19) {
          visibiltyIndex = 15;
          return;
        }
        visibiltyIndex++;
        break;
    }
  }

  bool _onKey(KeyEvent event) {
    final key = event.logicalKey.keyLabel;

    if (event is KeyDownEvent) {
      if (key == "Enter") {
        // final renderbox = key1.currentContext!.findRenderObject() as RenderBox;
        // // renderbox.size;
        // log("Size: ${renderbox.size}");

        // Save to clipboard

        saveToClipboard();
      } else if (key == "Arrow Down") {
        adjustVisibiltyindex(EnumArrow.down);
        updateSelectedIndex(EnumArrow.down);
      } else if (key == "Arrow Up") {
        adjustVisibiltyindex(EnumArrow.up);
        updateSelectedIndex(EnumArrow.up);
      } else if (key == "Arrow Left") {
        adjustVisibiltyindex(EnumArrow.left);
        updateSelectedIndex(EnumArrow.left);
      } else if (key == "Arrow Right") {
        adjustVisibiltyindex(EnumArrow.left);
        updateSelectedIndex(EnumArrow.right);
      } else if (key == "Escape") {
        exit(0);
      } else if (key == "1") {
        memeResults.clear();
        selectedIndex = 0;
        searchType.value = SearchType.ascii;
        if (searchText.isNotEmpty) {
          findAsciiEmoji();
        }
      } else if (key == "2") {
        selectedIndex = 0;
        memeResults.clear();
        searchType.value = SearchType.image;
        if (searchText.isNotEmpty) {
          findMeme();
        }
      } else if (key == "3") {
        selectedIndex = 0;
        memeResults.clear();
        searchType.value = SearchType.gif;
        if (searchText.isNotEmpty) {
          findGif();
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

  // Adjust scroll position if at the edge and the user presses up/down
  // void adjustScroll(bool goingUp) {
  //   if (searchResults.length <= maxResultsAtOnce) {
  //     return;
  //   }
  //   final scrollOffset = scrollController.offset;
  //   // selected Item index in viewport
  //   final itemsOutsideViewport = (scrollOffset / searchItemHeight).floor();
  //   final indexInViewport = (selectedIndex - itemsOutsideViewport);

  //   if (indexInViewport == 6 && !goingUp) {
  //     scrollController.animateTo((selectedIndex - 5) * searchItemHeight, duration: const Duration(milliseconds: 100), curve: Curves.easeIn);
  //   } else if (indexInViewport == 1 && goingUp) {
  //     scrollController.animateTo(scrollOffset - searchItemHeight, duration: const Duration(milliseconds: 100), curve: Curves.easeIn);
  //   }
  // }

  // Default height is 70
  void updateWindowSize() {
    final double calculatedHeight = searchBarSize + 3 + 5 + 30 + ((searchResults.length <= maxResultsAtOnce ? searchResults.length : maxResultsAtOnce) * 40);

    windowManager.setSize(Size(600, calculatedHeight));
  }

  void updateWindowSizeForImages() {
    windowManager.setSize(const Size(600, searchBarSize + 464));
  }

  void updateSelectedIndex(EnumArrow arrow) {
    // Check if something invisible
    // scrollController.
    // final int visibleIndex = scrollController.offset ~/ 145;
    // log("Visible index:${scrollController.offset} $visibleIndex");
    // switch (arrow) {
    //   case EnumArrow.up:
    //   case EnumArrow.left:
    //     break;
    //   case EnumArrow.down:
    //   // if (visibleIndex == 15 || visi){

    //   // }
    //   break;
    //   case EnumArrow.right:
    //     // if (visibiltyList[selectedIndex].visibleHeight != 116.0) {
    //     //   scrollController.jumpTo(scrollController.offset + (116.0 - visibiltyList[selectedIndex].visibleHeight));
    //     // }
    //     break;
    // }

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
    if (searchType.value == SearchType.ascii) {
      if (delta < searchResults.length && delta >= 0) {
        selectedIndex = delta;
        setState(() {});
      }
    } else {
      if (delta < memeResults.length && delta >= 0) {
        selectedIndex = delta;
        setState(() {});
      }
    }
    switch (arrow) {
      case EnumArrow.up:
        adjustScroll(true);
        break;
      case EnumArrow.down:
        adjustScroll(false);
        break;
      case EnumArrow.left:
        break;
      case EnumArrow.right:
        break;
    }
  }

  void adjustScroll(bool goingUp) {
    if (searchResults.length <= maxResultsAtOnce) {
      return;
    }
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
    memeResults.clear();
    log("Searching for memes with $searchText");
    final url = "https://g.tenor.com/v1/search?q=$searchText&key=LIVDSRZULELA&limit=15";
    try {
      http.get(Uri.parse(url)).then((response) {
        final json = jsonDecode(response.body);
        final data = json["results"] as List<dynamic>;
        for (final result in data) {
          try {
            memeResults.add(result["media"].first["mp4"]["preview"]);
          } catch (e) {
            log("Error parsing meme: $e");
          }
        }
        log("Memes length ${memeResults.length}");
        updateWindowSizeForImages();
        setState(() {});
      });
    } catch (e) {
      log("Error searching for memes: $e");
    }
  }

  void findGif() {
    memeResults.clear();
    log("Searching for memes with $searchText");
    final url = "https://g.tenor.com/v1/search?q=$searchText&key=LIVDSRZULELA&limit=15";
    try {
      http.get(Uri.parse(url)).then((response) {
        final json = jsonDecode(response.body);
        final data = json["results"] as List<dynamic>;
        for (final result in data) {
          try {
            memeResults.add(result["media"].first["mediumgif"]["url"]);
          } catch (e) {
            log("Error parsing meme: $e");
          }
        }
        log("Memes length ${memeResults.length}");
        updateWindowSizeForImages();
        setState(() {});
      });
    } catch (e) {
      log("Error searching for memes: $e");
    }
  }

  void findAsciiEmoji() {
    setState(() {
      searchResults = allEmojis.where((element) => element.shortName.toLowerCase().contains(searchText.toLowerCase())).toList();
    });
  }

  GlobalKey key1 = GlobalKey();
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
              Column(
                // key: key1,
                mainAxisSize: MainAxisSize.min,
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
                      } else {
                        findAsciiEmoji();
                        updateWindowSizeForImages();
                      }
                    },
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Text("(1)", style: TextStyle(color: Colors.grey.withOpacity(0.5))),
                            Text("  Ascii", style: TextStyle(color: isDarkMode ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.5))),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            Text("(2)", style: TextStyle(color: Colors.grey.withOpacity(0.5))),
                            Text("  Images", style: TextStyle(color: isDarkMode ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.5))),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            Text("(3)", style: TextStyle(color: Colors.grey.withOpacity(0.5))),
                            Text("  Gifs", style: TextStyle(color: isDarkMode ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.5))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (searchResults.isNotEmpty || memeResults.isNotEmpty)
                    Container(
                      height: 1,
                      margin: const EdgeInsets.only(bottom: 2),
                      width: double.maxFinite,
                      color: Colors.grey.withOpacity(0.5),
                    ),
                ],
              ),
              Expanded(
                  child: ValueListenableBuilder(
                      valueListenable: searchType,
                      builder: (context, SearchType value, child) {
                        if (memeResults.isEmpty && searchResults.isEmpty && hasFirstSearchHappened) {
                          return Center(
                            child: Text(
                              "Search : )",
                              style: TextStyle(color: isDarkMode ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.5)),
                            ),
                          );
                        }
                        if (value == SearchType.image || value == SearchType.gif) {
                          if (memeResults.isEmpty) {
                            return Center(
                              child: Text(
                                "Search Memes",
                                style: TextStyle(color: isDarkMode ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.5)),
                              ),
                            );
                          }
                          return LayoutBuilder(builder: (context, cons) {
                            // log("max width ${cons.maxWidth}");
                            return GridView(
                                controller: scrollController,
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: gridCrossAxisCount, childAspectRatio: 1),
                                children: List.generate(memeResults.length, (index) {
                                  return Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: selectedIndex == index
                                        ? BoxDecoration(
                                            color: Colors.white.withOpacity(0.6),
                                            borderRadius: BorderRadius.circular(10),
                                          )
                                        : null,
                                    child: CachedNetworkImage(
                                      imageUrl: memeResults[index],
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                                      errorWidget: (context, url, error) => const Icon(Icons.error),
                                    ),
                                  );
                                }));
                          });
                        }

                        return LayoutBuilder(builder: (context, cons) {
                          log("max height ${cons.maxHeight}");
                          return Container(
                            // color: Colors.red,
                            // key: key1,
                            child: GridView(
                                controller: scrollController,
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: gridCrossAxisCount, childAspectRatio: 1),
                                children: List.generate(searchResults.length, (index) {
                                  return SizedBox(
                                    key: index == 0 ? key1 : null,
                                    child: Container(
                                      alignment: Alignment.center,
                                      margin: const EdgeInsets.all(5),
                                      decoration: selectedIndex == index
                                          ? BoxDecoration(
                                              color: Colors.blue.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(10),
                                            )
                                          : null,
                                      child: Container(
                                        alignment: Alignment.center,
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              searchResults[index].shortName,
                                              style: TextStyle(color: isDarkMode ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.7)),
                                            ),
                                            const SizedBox(
                                              height: 10,
                                            ),
                                            Text(searchResults[index].emoji, style: TextStyle(color: isDarkMode ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.7))),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                  // return CachedNetworkImage(
                                  //   imageUrl: memeResults[index],
                                  //   fit: BoxFit.cover,
                                  //   placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                                  //   errorWidget: (context, url, error) => const Icon(Icons.error),
                                  // );
                                })),
                          );
                        });

                        // return ListView.builder(
                        //     controller: scrollController,
                        //     padding: const EdgeInsets.only(bottom: 5),
                        //     itemBuilder: (context, index) {
                        //       return SizedBox(
                        //         height: searchItemHeight,
                        //         child: Container(
                        //           padding: const EdgeInsets.symmetric(horizontal: 5),
                        //           decoration: BoxDecoration(color: selectedIndex == index ? Colors.blue.withOpacity(0.4) : Colors.transparent, borderRadius: BorderRadius.circular(5)),
                        //           child: Row(
                        //             children: [
                        //               Text(
                        //                 searchResults[index].shortName,
                        //                 style: TextStyle(color: isDarkMode ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.7)),
                        //               ),
                        //               const Spacer(),
                        //               Text(searchResults[index].emoji, style: TextStyle(color: isDarkMode ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.7))),
                        //             ],
                        //           ),
                        //         ),
                        //       );
                        //     },
                        //     itemCount: searchResults.length);
                      }))
            ],
          ),
        );
      }),
    );
  }
}
