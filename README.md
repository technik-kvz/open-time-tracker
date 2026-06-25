# Open Time Tracker Fork

This fork has some basic offline abilities (caches the last requests - only use when you are sure, users are never changes on running machine) and allows the use of custom fields in time records. There are 2 default custom types that we use, therefore there these fields have "hard coded" types and names.

This repo contains the source code for time tracking application. This app is a client for Open Project that allows users to easily track their time spent on various tasks, projects.  
You can also take a look at *[app's webpage](https://open-time-tracker.com)*

## How to run it locally

- Install flutter SDK and fvm
- Clone the repository
- Navigate to the cloned repository
- Download and install all the required dependencies
```
fvm flutter pub get
```
- Generate the required code for the app to run
```
fvm dart run build_runner build --delete-conflicting-outputs
```
- Connect your Android or iOS device to your computer, or launch an emulator
- Launch the app on your device or emulator
```
fvm flutter run
```
