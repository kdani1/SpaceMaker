# SpaceMaker

**SpaceMaker: Swipe left for storage**

Tinder-style photo and video cleaner for Android and iOS. Swipe left to trash, swipe right to keep. Filter by size, type, and age.

Photos stay on the phone. The local backend only stores accounts and the Plus flag.

## Test user

| | Email | Password | Plan |
| --- | --- | --- | --- |
| Plus | `test@spacemaker.app` | `SpaceMaker1!` | Yearly Plus |
| Free | `demo@spacemaker.app` | `SpaceMaker1!` | 20 free empties |

## Run locally

1. Start API: `.\start-backend.ps1` (port 8790)
2. Start APK host: `dotnet run --project host --urls http://0.0.0.0:8792`
3. Phone download: `http://192.168.0.249:8792/spacemaker.apk`
4. In the app, server URL: `http://192.168.0.249:8790`

## Name

Store title: `SpaceMaker: Swipe left for storage`  
Package: `app.spacemaker.swipe`

This is a local test build. Before a store release, run a lawyer-grade trademark search. `Space Maker Method` is a different decluttering-course app. `SPACEMAKER` also appears on some hardware marks (tablets / appliances), which is a different class than this photo utility.
