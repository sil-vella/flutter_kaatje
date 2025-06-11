import os
import xml.etree.ElementTree as ET


def update_android_manifest(privacy_policy_url):
    """Update AndroidManifest.xml with the privacy policy URL."""
    manifest_path = "android/app/src/main/AndroidManifest.xml"
    if not os.path.exists(manifest_path):
        print(f"AndroidManifest.xml not found at {manifest_path}")
        return False

    ET.register_namespace('android', 'http://schemas.android.com/apk/res/android')  # Ensure namespace registration
    try:
        tree = ET.parse(manifest_path)
    except ET.ParseError as e:
        print(f"Error parsing AndroidManifest.xml: {e}")
        return False

    root = tree.getroot()
    application = root.find("application")
    if application is None:
        print("No <application> tag found in AndroidManifest.xml.")
        return False

    # Check if meta-data for privacy policy already exists
    meta_data = application.find("./meta-data[@android:name='privacy_policy_url']", namespaces={'android': 'http://schemas.android.com/apk/res/android'})
    if meta_data is not None:
        meta_data.attrib['{http://schemas.android.com/apk/res/android}value'] = privacy_policy_url
        print("Updated privacy policy URL in AndroidManifest.xml.")
    else:
        ET.SubElement(application, "meta-data", {
            '{http://schemas.android.com/apk/res/android}name': 'privacy_policy_url',
            '{http://schemas.android.com/apk/res/android}value': privacy_policy_url
        })
        print("Added privacy policy URL to AndroidManifest.xml.")

    # Save changes
    try:
        tree.write(manifest_path, encoding="utf-8", xml_declaration=True)
    except IOError as e:
        print(f"Error writing to AndroidManifest.xml: {e}")
        return False

    return True


def update_ios_info_plist(privacy_policy_url):
    """Update Info.plist with the privacy policy URL."""
    info_plist_path = "ios/Runner/Info.plist"
    if not os.path.exists(info_plist_path):
        print(f"Info.plist not found at {info_plist_path}")
        return False

    with open(info_plist_path, "r") as file:
        plist_data = file.read()

    # Check if PrivacyPolicyURL already exists
    if "<key>PrivacyPolicyURL</key>" in plist_data:
        # Replace the existing URL
        plist_data = plist_data.replace(
            plist_data.split("<key>PrivacyPolicyURL</key>")[1].split("<string>")[1].split("</string>")[0],
            privacy_policy_url
        )
        print("Updated privacy policy URL in Info.plist.")
    else:
        # Add new key-value pair for PrivacyPolicyURL
        insert_point = plist_data.rfind("</dict>")
        new_entry = f"\n\t<key>PrivacyPolicyURL</key>\n\t<string>{privacy_policy_url}</string>\n"
        plist_data = plist_data[:insert_point] + new_entry + plist_data[insert_point:]
        print("Added privacy policy URL to Info.plist.")

    # Save changes
    with open(info_plist_path, "w") as file:
        file.write(plist_data)
    return True


def check_icons():
    """Check for missing app icons in Android and iOS."""
    print("\n--- Checking Icons ---")

    # Android icons
    android_icon_paths = [
        "android/app/src/main/res/mipmap-hdpi/ic_launcher.png",
        "android/app/src/main/res/mipmap-mdpi/ic_launcher.png",
        "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png",
        "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png",
        "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png"
    ]

    print("\nAndroid Icons:")
    for path in android_icon_paths:
        if os.path.exists(path):
            print(f"✅ {path}")
        else:
            print(f"❌ {path} is missing!")

    # iOS icons
    ios_icon_paths = [
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png",
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png",
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png",
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png",
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png",
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png",
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png",
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png",
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png",
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png"
    ]

    print("\niOS Icons:")
    for path in ios_icon_paths:
        if os.path.exists(path):
            print(f"✅ {path}")
        else:
            print(f"❌ {path} is missing!")


def main():
    print("--- Flutter Project Settings Update Script ---")

    # Prompt for app name
    app_name = input("Enter the App Name (or press Enter to skip): ").strip()
    if app_name:
        print(f"App Name set to: {app_name}")

    # Prompt for app ID
    app_id = input("Enter the App ID / Package Name (or press Enter to skip): ").strip()
    if app_id:
        print(f"App ID set to: {app_id}")

    # Prompt for Privacy Policy URL
    privacy_policy_url = input("Enter the Privacy Policy URL (or press Enter to skip): ").strip()

    # Update Android settings
    if input("Check Android settings? (y/n): ").strip().lower() == "y":
        if privacy_policy_url:
            update_android_manifest(privacy_policy_url)

    # Update iOS settings
    if input("Check iOS settings? (y/n): ").strip().lower() == "y":
        if privacy_policy_url:
            update_ios_info_plist(privacy_policy_url)

    # Check app icons
    if input("Check app icons? (y/n): ").strip().lower() == "y":
        check_icons()

    print("\nSettings update completed.")


if __name__ == "__main__":
    main()
