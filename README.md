# ⌨️ retro_typer

A simple emoji/memes finder

# 💻 Screenshots

![alt text](./videos/retro_typer.gif)

![alt text](./videos/emojis.png)
![alt text](./videos/ascii.png)

# 🛠️ How to use

<video width="500" height="300" controls>
  <source src="/videos/use_video.mp4" type="video/mp4">
Your browser does not support the video tag.
</video>

- Use arrow keys to choose the meme to use
- Press number keys on keyboard to choose type 1 for ascii, 2 for gif etc
- Press enter to choose. The meme/emoji has been copied to clipboard


# 🔥 Installation for macos

<video width="500" height="300" controls>
  <source src="/videos/macos_setup.mp4" type="video/mp4">
Your browser does not support the video tag.
</video>


1. Download retro_typer.dmg from [Releases](https://github.com/K-Rafiki/retro_emojis/releases/tag/v4.0)
2. Double click and install the .dmg file

#### ⏩ Setup Shortcut to run the retro_typer
1. Open the Shortcuts app in macos
2. Click the plus button at the top right corner to add a new shortcut
3. click on the search bar at the top right corner and type "Open App" for the action. Drag open app to the main area.
4. Click on the app keyword and find retro_typer
5. To setup a keyboard shortcut, click the information icon at the top right corner of the shortcuts app.
6. Click "Add Keyboard Shortcut" and add your shortcut key combination, you can press shift + option + 1
6. And you're done ! Just press the shortcut anywhere.

![alt text](./videos/screenshot.png)


# 🔥 Installation for windows

1. Download windows.zip from [Releases](https://github.com/K-Rafiki/retro_emojis/releases/tag/v4.0)
2. extract the zip file

#### ⏩ Setup Shortcut to run retro_typer

1. Right click on the retro_typer shortcut and click 'properties'
2. click on the 'Shortcut Key' and setup a key like Ctrl + Alt + 1


# 👷 Build your own dmg

If you want to build your own dmg instead of the releases, you can follow this [article](https://retroportalstudio.medium.com/creating-dmg-file-for-flutter-macos-apps-e448ff1cb0f). I'll mention the steps here regardless.
You need to have flutter installed.

Clone the Repository
```
git clone https://github.com/K-Rafiki/retro_emojis
```

Create a release build.
```
flutter build macos --release
```

Run the following command in your terminal. Make sure you have npm installed.

```
npm install -g appdmg
```

Finally we build the dmg
```
appdmg ./dmg_creator/config.json ./dmg_creator/retro_typer.dmg
```


## 🏗️ TODO
- [X] Add normal emojis
- [X] Add Gifs
- [X] Recently used appear at the top
- [X] Add settings for configuration


## 🚁 Contributions

Contributions are always welcome ! Send in a PR request, I'll review and merge


## Known Issues

Some shortcuts are already used by the Macos itself. Try out a few combinations and see which ones are available
This is a known issue. If you have resolved it, you can reach out to me or create a PR with help and I can merge !


