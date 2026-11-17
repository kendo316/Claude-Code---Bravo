#!/bin/bash
# Builds the app, runs it in an iPhone simulator with six made-up screenshots in Photos,
# and saves a picture of each main screen into shots/. Run by .github/workflows/build.yml.
set -euo pipefail
BUNDLE=com.kendo316.finderskeepers
mkdir -p shots

UDID=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
phones = [d for runtime, devs in json.load(sys.stdin)["devices"].items() if "iOS" in runtime for d in devs if d["name"].startswith("iPhone")]
exact = [d for d in phones if d["name"] == "iPhone 17"]
print((exact or phones)[0]["udid"])')
echo "Simulator: $UDID"
xcrun simctl boot "$UDID" || true
xcrun simctl bootstatus "$UDID" -b | tail -1

xcodebuild -project FindersKeepers.xcodeproj -scheme FindersKeepers -configuration Debug \
  -destination "id=$UDID" -derivedDataPath build build 2>&1 | grep -E "(error|warning): |BUILD (SUCCEEDED|FAILED)" | sort -u || true
APP=build/Build/Products/Debug-iphonesimulator/FindersKeepers.app
test -d "$APP"

xcrun simctl addmedia "$UDID" Tests/Fixtures/*.png
xcrun simctl install "$UDID" "$APP"
xcrun simctl privacy "$UDID" grant photos "$BUNDLE"
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 || true

shoot() {   # shoot <name> <seconds to wait> [launch options...]
  local name=$1 wait=$2; shift 2
  xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
  xcrun simctl launch "$UDID" "$BUNDLE" "$@"
  sleep "$wait"
  xcrun simctl io "$UDID" screenshot "shots/$name.png"
}

shoot 1-pile 45
shoot 2-search 8 -debugSearch tbsp
shoot 3-detail 10 -debugDetail YES
shoot 4-weekly 8 -debugTab weekly
shoot 5-look 12 -debugTab weekly -debugLook YES
shoot 6-more 8 -debugTab more

# What the app read from each made-up screenshot.
DATA=$(xcrun simctl get_app_container "$UDID" "$BUNDLE" data)
cp "$DATA/Library/Application Support/cards.json" shots/cards.json 2>/dev/null || echo "no cards.json yet"
python3 - <<'PY'
import json, pathlib
p = pathlib.Path("shots/cards.json")
if p.exists():
    state = json.loads(p.read_text())
    for c in state["cards"]:
        print("CARD|", c.get("title"), "|", c.get("group"), "| read:", c.get("isRead"), "| dates:", len(c.get("dates", [])),
              "| address:", c.get("address"), "| links:", c.get("links"), "| chars:", len(c.get("text", "")))
PY
ls ~/Library/Logs/DiagnosticReports/ 2>/dev/null | grep -i finders && echo "CRASH REPORT FOUND" || echo "no crash reports"
