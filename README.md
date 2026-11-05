# Lumen Launcher

iOS-style home screen launcher for Android (Flutter).

## Features
- Rounded-square (squircle) icons, glass dock, page dots, smooth page swipes
- Long-press empty space → edit mode: icons wiggle, drag to rearrange, drag to screen edge to change page
- Drag one app onto another → folder (rename, remove from folder)
- Long-press an icon → preview menu (Edit Home Screen, App Info, Remove App)
- "Remove App" → Delete App / Remove from Home Screen (app stays in Library)
- Widgets: Weather, Calendar, analog Clock, Battery, Suggestions, month Calendar
- Today view (swipe right from first page), Library (last page, apps grouped by category + A–Z search)
- Swipe down → Search (apps, quick calculator, web, Play Store)
- Swipe down from top-right → Controls: Wi-Fi/Bluetooth/Airplane/Data, music play/pause/next, brightness, volume, flashlight, timer, calculator, camera…
- Swipe down from top-left → notification shade
- Apps open with a zoom-from-icon animation
- Built-in gradient wallpapers or any photo from the gallery
- New apps automatically added to the Home Screen

## APK kaise banaye (GitHub Actions)
1. GitHub pe naya repo banao (jaise `Lumen-Launcher`).
2. Is folder ke andar terminal kholo aur:
   ```
   git init
   git add .
   git commit -m "Lumen launcher"
   git branch -M main
   git remote add origin https://github.com/<username>/Lumen-Launcher.git
   git push -u origin main
   ```
3. Repo → **Actions** → "Build APK" (~8-10 min) → **Artifacts** → `lumen-apk` download.

## Phone pe setup
1. APK install karo, Lumen kholo.
2. Today view ke neeche ya edit mode mein **Settings** → **Set as Default Home App** → Lumen select karo.
3. Settings mein apna city likho (weather ke liye) aur wallpaper chuno.
4. Brightness slider pehli baar use karne par "Modify system settings" permission maangega — allow karo.

## Android ki limits
- Lock screen badalna kisi bhi launcher ke liye possible nahi.
- Wi-Fi/Bluetooth Android 10+ par apps seedha on/off nahi kar sakti — tile tap karne par system ka quick panel khulta hai.
- Notification shade wala gesture kuch phones par kaam na kare to normal status bar se neeche swipe karo.
