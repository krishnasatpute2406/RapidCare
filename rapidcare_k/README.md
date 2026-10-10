# RapidCare Flutter app

## Connect to the Flask server

The backend must be running on port `5000`.

- **Android emulator:** the app uses `http://10.0.2.2:5000` automatically.
- **Flutter web on the same computer:** the app uses the browser host on port `5000` automatically.
- **Physical Android phone:** connect the phone and computer to the same Wi-Fi, find the computer's current IPv4 address with `ipconfig`, then run from this folder:

  ```powershell
  flutter run --dart-define=API_BASE=http://<COMPUTER-IPv4>:5000
  ```

  Replace `<COMPUTER-IPv4>` with the address shown under the computer's active Wi-Fi adapter. If it changes, use the new address next time. Keep Flask listening on `0.0.0.0:5000` and allow port `5000` through Windows Firewall for the private network.

For USB debugging, `adb reverse tcp:5000 tcp:5000` can be used, then launch with `--dart-define=API_BASE=http://127.0.0.1:5000`.

## Live location

Allow location access in Android or the browser and turn on device Location Services. Best GPS results usually require an unobstructed view of the sky. The app shows the reported accuracy and does not use its map framing point as a patient or ambulance location. Hospital map pins come from the project directory; a hospital staff member can update its pin only while physically at that hospital.
