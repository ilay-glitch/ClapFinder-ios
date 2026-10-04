#!/usr/bin/env python3
"""Generates QA_CHECKLIST.html — the manual QA pass for Guard Dog (Android).

Edit the SECTIONS data below, then run:  python3 scripts/gen-qa-doc.py
Row ids are derived from the section number and the row text, so editing a row's
wording resets that row's saved mark (deliberately: the check changed).
"""
import datetime
import hashlib
import html
import pathlib

BUILD = "1.0.0"
OUT = pathlib.Path(__file__).resolve().parent.parent / "QA_CHECKLIST.html"

TAGS = {
    "listen": "Listen",
    "lock": "Locked phone",
    "pocket": "Pocket",
    "call": "Second phone",
    "adb": "Computer",
    "settings": "Phone settings",
    "talkback": "TalkBack",
    "bt": "Bluetooth",
    "long": "30+ minutes",
    "clock": "Change the clock",
    "vpn": "EU VPN",
}

# Each row: (text_html, {"tags": [...], "req": "...", "guard": bool}) or a "## Group" string.
# `guard` rows are the amber-edged ones: a failure means the phone is not really
# protected, or a thief can silence it, or the user is misled about being guarded.
R = lambda text, *tags, req=None, guard=False: (text, {"tags": list(tags), "req": req, "guard": guard})

SECTIONS = [
    ("Before you start", "Read this section first. A few of these decide whether the pass is useful at all.", [
        R("You are testing on a <b>real phone</b>, not an emulator. An emulator has no real motion or proximity sensor, no torch and no vibration motor, so most of this list means nothing there."),
        R("You have written the phone’s model, Android version and which APK you installed in the box below. A result without a device is not a result."),
        R("You are using <code>GuardDog-1.0.0-release-test.apk</code> for this pass. The debug APK is slower and is only for reading logs."),
        R("If you can, run the pass on at least <b>two brands</b>, one of them Samsung or Xiaomi. Those brands close background apps aggressively and section 08 depends on it."),
        R("You have a <b>second phone</b> that can call this one.", "call"),
        R("You have a pocket you can actually put the phone in: trousers or a jacket, not a bag.", "pocket"),
        R("Ringer and alarm volume are <b>not</b> at maximum. Set alarm volume to about half so you can tell when the app raises it."),
        R("You have read the last section, <b>Not bugs</b>. It lists what is deliberately missing or deliberately strict, so you do not spend time reporting it."),
    ]),
    ("Install and first launch", "Uninstall any older copy first, so this is a genuine first run.", [
        R("The APK installs. The app appears in the launcher as <code>Guard Dog</code>."),
        R("Its icon is the <b>golden puppy in a navy police cap</b> holding a blue shield, on a sky-blue background. Ears hang down; they are never pointed up."),
        R("On a launcher with round or squircle icons, the dog’s face, cap and shield are all visible. Nothing important is cut off by the shape."),
        R("Tapping the icon shows a sky-blue launch screen (with the round icon, on Android 12 and newer), then the app’s own splash. There is <b>no white or black flash</b> between them."),
        R("The splash shows <code>Guard Dog</code>, the line <code>Nobody touches your phone. Ever. 🐶🛡️</code>, the dog with the shield gently bobbing, and blue rings pulsing behind it."),
        R("A progress bar and <code>Loading N%…</code> fill to 100%. The number only ever goes up.", req="§1.5"),
        R("On this first launch the splash does <b>not</b> say <code>This action can contain ads</code>, and no ad appears.", req="§3"),
        R("The splash lasts about <b>1.5 to 2 seconds</b>, then onboarding appears."),
    ]),
    ("Onboarding", "Shown only on the very first launch. Three steps.", [
        R("Step 1 reads <code>STEP 1 OF 3</code>, shows the waving dog, the card <code>I’ll guard your phone!</code> / <code>Put me on watch — if anyone touches your phone, I bark 🐶🛡️</code>, and a blue <code>Continue</code> button."),
        R("Step 2 reads <code>STEP 2 OF 3</code>, shows a bell with rings and a small sitting dog, the card <code>If guarding stops, you’ll know</code> / <code>I’ll send a notification if anything interrupts my watch 🔔</code>, and <code>Enable Notifications</code>."),
        R("Tapping <code>Enable Notifications</code> shows Android’s own notification prompt (Android 13 and newer). On older Android it goes straight to step 3."),
        R("Choosing <b>Allow</b> moves on to step 3."),
        R("On a fresh install, choosing <b>Don’t allow</b> also moves on to step 3. The app never blocks you for refusing."),
        R("Step 3 reads <code>STEP 3 OF 3</code>, shows the dog with the shield, the card <code>Ready to stand guard.</code> / <code>Arm me whenever you leave your phone.</code>, and <code>Start</code>."),
        R("<code>Start</code> opens the home screen on the <b>Don’t Touch</b> tab."),
        R("Close the app completely and open it again. Onboarding does <b>not</b> appear again, ever."),
        R("Text in every card fits. Nothing is cut off, overlapping, or running under the button."),
    ]),
    ("Home — the Don’t Touch tab", "Look before you arm anything.", [
        R("The background is sky blue with soft shields and paw prints, slightly washed out so text stays readable."),
        R("Top to bottom: <code>Guard Dog</code>, <code>Don’t touch my phone!</code>, the dog standing with its shield, a white ring with a faint 🛡️ inside, then <code>Tap the shield to arm</code>."),
        R("Under the status is one line: <code>Arm it, set your phone down — any movement sets off the alarm.</code>"),
        R("<code>Choose your guard</code> sits above a grid of <b>16 cards</b> in rows of four: Dog, Cat, Cow, Frog, Duck, Pig, Rooster, Sheep, Siren, Alarm Clock, Air Horn, Bell, Whistle, Beeper, Doorbell, Foghorn. Each has its emoji."),
        R("On first launch <b>Dog</b> is selected: light blue fill and a blue border. No other card looks selected."),
        R("Below the grid is <code>Sensitivity</code> with <code>Low</code>, <code>Medium</code>, <code>High</code>. <b>Medium</b> is selected."),
        R("The page scrolls smoothly to the sensitivity control. Nothing is hidden behind the bottom tab bar."),
        R("The bottom bar has two tabs, <code>🛡️ Don’t Touch</code> and <code>👖 Pocket Mode</code>. The current one is highlighted."),
        R("Tapping a different card selects it and deselects the old one. Only one card is ever selected."),
        R("Tapping a different sensitivity selects it. Only one is ever selected."),
        R("Card names are not cut off on a small phone (<code>Alarm Clock</code> is the longest)."),
    ]),
    ("Arming — the 5-second grace", "Hold the phone in your hand for this section. Movement is ignored during the grace, which is the point.", [
        R("Tap the shield. It turns <b>solid blue</b> and shows a large <code>5</code>, counting down 5, 4, 3, 2, 1, once a second.", req="§1.2"),
        R("A blue ring around the button shrinks as the count goes down."),
        R("The status reads <code>Arming — put your phone down…</code>. The one-line explanation underneath disappears."),
        R("The dog above changes to the <b>sitting, watching</b> pose."),
        R("Shake the phone during the countdown. <b>No alarm.</b> Motion during the grace is ignored.", guard=True, req="§1.2"),
        R("Tap the button again during the countdown. It stops, you hear the <b>chirp-chirp</b>, and everything returns to <code>Tap the shield to arm</code>. No alarm.", "listen"),
        R("A notification appears while arming: <code>Guard Dog</code> / <code>Arming — 4…</code>, counting down with the screen."),
    ]),
    ("Armed — monitoring", "Arm again and put the phone flat on a solid table. Do not touch it.", [
        R("When the count reaches the end you hear a short <b>double beep</b> (chirp-chirp), like a car remote locking.", "listen", req="§1.1"),
        R("The status turns green with a dot: <code>Armed — don’t touch 🛡️</code>."),
        R("Blue rings pulse out from the shield, over and over."),
        R("The phone lies untouched for <b>2 minutes</b>. No alarm goes off by itself.", guard=True),
        R("Pull down the notification shade. There is a <code>Guard Dog</code> notification reading <code>Armed — don’t touch 🛡️</code> with a <code>Disarm</code> button. It cannot be swiped away.", req="§1.2"),
        R("Tapping the notification body (not the button) opens the app, still armed."),
        R("Tap the shield while armed (no alarm). You hear the chirp, the shield goes back to white and the status to <code>Tap the shield to arm</code>. The notification disappears.", "listen"),
    ]),
    ("The alarm", "Arm, wait for the chirp, then pick the phone up like a thief would.", [
        R("Picking the phone up sets off the alarm within <b>about half a second</b>.", guard=True, req="§1.2"),
        R("The sound is the <b>guard you selected</b>, looping without gaps.", "listen"),
        R("It is <b>loud</b>: clearly louder than the half-way alarm volume you set earlier. Check the alarm volume slider afterwards: it was raised to the top during the alarm.", "listen", guard=True, req="§4.5"),
        R("The <b>flashlight flashes</b> rapidly on the back of the phone.", guard=True, req="§4.2"),
        R("The phone <b>vibrates</b> in a repeating pattern, about once a second."),
        R("The whole screen turns dark red. A big emoji of your selected guard bounces in the middle, with <code>Motion detected!</code> under it and a big blue <code>DISARM</code> button at the bottom."),
        R("The emoji is the <b>selected guard’s</b> emoji (for example 🐮 for Cow), not a picture of the dog.", req="§1.4"),
        R("The red screen also covers the tab bar. Tapping where the tabs are, or anywhere except DISARM, does nothing.", guard=True, req="§1.1"),
        R("Pressing the system <b>Back</b> button or gesture does nothing. The alarm keeps going.", guard=True),
        R("Pressing <b>volume down</b> repeatedly does not make the alarm quieter for more than a moment.", "listen", guard=True),
        R("A heads-up notification <code>🚨 Motion detected!</code> / <code>Guard Dog caught someone touching your phone!</code> appears, then buzzes again about <b>5 s</b> and <b>10 s</b> later. Three in total.", req="§1.2"),
        R("Press <b>Home</b> during the alarm. The sound, flashing and vibration all continue. Open the app again: the red screen is still there.", "listen", guard=True, req="§1.3"),
        R("Lock the phone with the power button during the alarm. The sound keeps going while locked.", "lock", "listen", guard=True),
        R("Leave it alarming for <b>one minute</b>. It never stops by itself. There is no timeout.", "listen", guard=True, req="§1.1"),
    ]),
    ("Disarming — every way out", "DISARM is the only way to stop an alarm. Check that it stops everything, every time.", [
        R("Tap <code>DISARM</code>. The sound stops <b>immediately</b>, the flashlight goes off and stays off, and the vibration stops.", "listen"),
        R("You hear the same chirp-chirp as when it armed.", "listen", req="§1.1"),
        R("The red screen fades away and the home screen shows <code>Tap the shield to arm</code>."),
        R("Disarm within 3 seconds of the alarm starting, then wait 15 seconds. <b>No</b> <code>Motion detected!</code> notification arrives late.", guard=True, req="§1.2"),
        R("After disarming, the <code>Motion detected!</code> notifications are gone from the shade, and so is the ongoing <code>Guard Dog</code> notification."),
        R("Check the alarm volume slider: it is back to the half-way level you set before the alarm."),
        R("Arm, then lock the phone. Pull down the shade on the lock screen and tap <code>Disarm</code>. The phone asks you to <b>unlock first</b>. It only disarms after you unlock.", "lock", guard=True),
        R("Arm, let the alarm start, then use the notification’s <code>Disarm</code> button (unlock when asked). Everything stops, exactly as with the big button.", "lock"),
        R("Arm and disarm ten times in a row quickly. You never hear two alarm sounds at once, the flashlight is never left on, and the app does not crash.", "listen"),
    ]),
    ("Screen off and background", "The point of the app is that it works while you are away. Each row starts armed and past the chirp.", [
        R("Lock the phone with the power button and leave it on the table for <b>1 minute</b>. Pick it up. The alarm goes off <b>while still locked</b>.", "lock", guard=True, req="§4.4"),
        R("In the same locked alarm, the <b>flashlight flashes</b>. (If it does not, write the phone model in Notes. This is one of the things we need to learn per brand.)", "lock", guard=True, req="§4.2"),
        R("While locked and armed, the lock screen shows the <code>Guard Dog</code> notification with <code>Armed — don’t touch 🛡️</code>.", "lock"),
        R("Press Home (do not lock), put the phone down for a minute, pick it up. The alarm goes off.", guard=True),
        R("Open the recent-apps screen and swipe Guard Dog away while armed. The status notification stays, and picking the phone up still sets off the alarm.", guard=True),
        R("Lock the phone and leave it armed for <b>30 minutes</b>. Pick it up. The alarm still goes off. Note the battery percentage before and after.", "lock", "long", guard=True, req="§4.4"),
        R("If the phone killed the app during that time, a notification <code>Touch Alert stopped</code> / <code>The system interrupted monitoring. Your phone is not being watched right now.</code> appears, either straight away or the next time you open the app. You are <b>never</b> left thinking it is guarding when it is not.", guard=True, req="§1.1"),
        R("Lock the phone with the app open, let the alarm go off, then unlock. You land on the red alarm screen with DISARM. (If the app was in the background, tapping the <code>Motion detected!</code> notification takes you there.)", "lock"),
    ]),
    ("Sensitivity", "Sensitivity is read when you arm. Changing it while armed applies to the next arm.", [
        "## Low",
        R("Set <b>Low</b>, arm, wait for the chirp. Tapping the table next to the phone does <b>not</b> set it off."),
        R("On Low, picking the phone up normally <b>does</b> set it off.", guard=True),
        "## Medium",
        R("Set <b>Medium</b>, arm. Sliding the phone a few centimetres across the table sets it off.", guard=True),
        R("On Medium, someone walking past the table does not set it off."),
        "## High",
        R("Set <b>High</b>, arm. A gentle nudge of the phone sets it off.", guard=True),
        R("On High, put the phone on a table and tap the table firmly a few times. Record in Notes whether it went off. (This is a known weak spot; we need the data, not a pass.)"),
        "## Persistence",
        R("Choose High, close the app completely, reopen. High is still selected."),
    ]),
    ("Every guard sound", "Select each guard, arm, wait for the chirp, pick the phone up, listen, then DISARM. Each one must loop, be loud, and match its name.", [
        *[R(f"<b>{name}</b> {emoji}: plays a {desc}, loops cleanly, and the alarm screen shows {emoji}.", "listen")
          for name, emoji, desc in [
              ("Dog", "🐕", "dog barking"), ("Cat", "🐈", "cat meowing"), ("Cow", "🐮", "cow mooing"),
              ("Frog", "🐸", "frog ribbiting"), ("Duck", "🦆", "duck quacking"), ("Pig", "🐖", "pig oinking"),
              ("Rooster", "🐔", "rooster crowing"), ("Sheep", "🐑", "sheep baaing"), ("Siren", "🚨", "siren"),
              ("Alarm Clock", "⏰", "digital alarm buzzer"), ("Air Horn", "📢", "air horn"),
              ("Bell", "🔔", "ringing bell"), ("Whistle", "🎵", "referee whistle"), ("Beeper", "🔊", "alarm beep"),
              ("Doorbell", "🚪", "ding-dong doorbell"), ("Foghorn", "🚢", "deep horn"),
          ]],
        R("Select <b>Cat</b> while armed with Dog. The alarm still plays <b>Dog</b>. The next arm uses Cat."),
        R("Close the app completely and reopen. The last guard you selected is still selected."),
    ]),
    ("Pocket Mode", "Switch to the Pocket Mode tab. Use a real pocket.", [
        R("The tab shows <code>Pocket Mode</code>, the sitting dog, a big <b>white circle with 👖</b>, <code>Tap to guard your pocket</code>, and the line <code>Arm it, slide the phone in your pocket — pulling it out sets off the alarm.</code>"),
        R("There is <b>no</b> sensitivity control and no guard grid on this tab. The guard chosen on Don’t Touch is used here.", req="§1.4"),
        R("Tap the circle. It turns <b>blue with 👀</b>, and the status reads <code>Screen on — slide me into your pocket…</code>."),
        R("Slide the phone into your pocket, screen on. The screen goes <b>black</b> when covered, and after about <b>1.5 seconds</b> you hear the chirp-chirp <b>through the fabric</b>.", "pocket", "listen", req="§1.3"),
        R("While in the pocket, walking around, sitting down and standing up do <b>not</b> set it off.", "pocket", guard=True),
        R("While the screen is black in the pocket, pressing on the phone through the fabric does not disarm it or change anything.", "pocket", guard=True),
        R("Pull the phone out. Within <b>about half a second</b> the screen lights up and the full alarm starts: sound, flashing, vibration, red screen with your guard’s emoji and <code>Phone pulled out!</code>.", "pocket", "listen", guard=True, req="§1.3"),
        R("DISARM stops everything and chirps, exactly as in Don’t Touch.", "listen"),
        R("Arm, then just cover the top of the phone with your hand for <b>less than a second</b> and uncover. It does <b>not</b> engage (no chirp)."),
        R("Arm, then tap the circle again before pocketing. It cancels with a chirp and returns to <code>Tap to guard your pocket</code>.", "listen"),
        R("Arm and leave it out of the pocket for 2 minutes. It stays waiting. There is no timeout."),
        R("Arm, then lay the phone <b>face down</b> on a desk. It engages (chirp). Lifting it sets off the alarm. This is intended.", "listen"),
        R("Arm, pocket it until the chirp, then lock the phone with the power button while it is in the pocket. Pull it out after 30 seconds. Write in Notes whether the alarm went off. (We need this answer per brand.)", "pocket", "lock", req="§4.1"),
        R("While engaged, the shade shows <code>Guard Dog</code> / <code>On duty in your pocket 👀</code> with <code>Disarm</code>."),
        R("While alarming, pressing Home or Back does not stop the alarm.", "pocket", guard=True, req="§1.3"),
    ]),
    ("Switching between modes", "Only one mode can be armed at a time.", [
        R("Arm Don’t Touch. Switch to the Pocket tab without disarming. The Don’t Touch guard is still armed (status notification still says <code>Armed</code>)."),
        R("From that state, arm Pocket Mode. Don’t Touch is disarmed (chirp) and Pocket starts. Going back to the Don’t Touch tab shows it disarmed.", "listen", req="§1.1"),
        R("Arm Pocket, then arm Don’t Touch. Pocket is disarmed and Don’t Touch starts its countdown."),
        R("Only one <code>Guard Dog</code> status notification ever shows at a time."),
    ]),
    ("The volume tip", "A one-time card after the first time you finish a guard session yourself.", [
        R("After a fresh install, arm Don’t Touch, cancel during the countdown. <b>No</b> tip appears."),
        R("Arm, let it alarm, DISARM. <b>No</b> tip appears. Dismissing an alarm does not count."),
        R("Arm, wait for the chirp, then disarm by tapping the shield. A cream card appears: <code>🔊 Louder = safer</code> / <code>The alarm plays at full alarm volume — even with your ringer on silent or vibrate. Keep alarms allowed in Do Not Disturb.</code> with <code>Got it</code>."),
        R("The same tip appears if the first finished session was in Pocket Mode (disarm with the circle after the chirp)."),
        R("<code>Got it</code> hides it. It never comes back, even after restarting the app."),
    ]),
    ("Sound settings and interruptions", "How the alarm behaves with the phone’s own sound settings and with other things going on.", [
        R("Ringer set to <b>Silent</b> or <b>Vibrate</b>: the chirp and the alarm are both still audible.", "listen", guard=True, req="§4.5"),
        R("With <b>Do Not Disturb</b> on (alarms allowed, the default), the alarm is audible. Write in Notes what happens if alarms are not allowed in DND.", "settings", "listen", req="§4.5"),
        R("Music playing in another app before the alarm: when the alarm starts, the music pauses or goes quiet and the alarm is clearly heard.", "listen"),
        R("Bluetooth earbuds connected and in the case: the alarm plays from the <b>phone’s speaker</b> (also fine if it plays on both). Write in Notes where you heard it.", "bt", "listen", guard=True),
        R("While armed (no alarm), have the second phone call this one. Write in Notes what happened: the call can ring, and picking up the phone to answer may set off the alarm. That is expected, it is being moved.", "call"),
        R("During an alarm, have the second phone call this one. The alarm keeps sounding or comes back after the call. It never ends up silently disarmed.", "call", "listen", guard=True),
    ]),
    ("Notifications", "", [
        R("Turn off Guard Dog notifications in Android settings. Arm Don’t Touch. It still guards and still alarms. Only the notifications are missing.", "settings", guard=True),
        R("Open Android settings → Apps → Guard Dog → Notifications. There are three categories: <code>Guard status</code>, <code>Alarms</code>, <code>Guarding stopped</code>.", "settings"),
        R("The <code>Guard status</code> notification never makes a sound or vibrates by itself."),
        R("Tapping the <code>Touch Alert stopped</code> notification opens the app, disarmed."),
        R("Tapping a <code>Motion detected!</code> notification opens the app on the red alarm screen."),
        R("The small status-bar icon is a <b>white shield</b>, not a grey square."),
    ]),
    ("Ads", "This build uses Google’s test ads. They are labelled <code>Test Ad</code>. Real ads come later.", [
        "## Launch ad",
        R("The very first launch shows <b>no ad</b> and no ad message (checked in section 01).", req="§3"),
        R("Close the app completely and open it again. The splash may show <code>This action can contain ads</code> while it loads. Within <b>5 seconds</b> either a full-screen test ad appears or the app goes to the home screen.", req="§3"),
        R("If a launch ad appears, closing it goes straight to the home screen."),
        R("Leave the app with Home and come back after a minute. <b>No</b> splash and no ad. Ads only come on a fresh start.", req="§3"),
        R("After a launch ad was shown, close and reopen the app. No second launch ad appears (it needs 4 hours between them).", req="§3"),
        R("Move the phone’s clock forward 5 hours, close and reopen the app. A launch ad may appear again.", "clock", req="§3"),
        "## Between sessions",
        R("Finish guard sessions by arming, waiting for the chirp and disarming with the shield or circle. A full-screen test ad appears after <b>3 to 5</b> finished sessions, right after you disarm.", req="§3"),
        R("A full-screen ad <b>never</b> appears while counting down, while armed, while alarming, or right after tapping DISARM on the alarm screen.", guard=True, req="§3"),
        R("Cancelling during the countdown never brings up an ad, however many times you do it.", req="§3"),
        R("There is <b>no banner ad</b> anywhere in the app.", req="§3"),
        "## Consent",
        R("With a VPN set to an EU country, on a fresh install, a Google privacy consent form appears on reaching the home screen. Whatever you choose, the app keeps working.", "vpn"),
    ]),
    ("Restarts and layout", "", [
        R("Close the app completely and reopen it (not the first launch). Splash, then straight to home. No onboarding."),
        R("Rotate the phone with auto-rotate on. The app stays upright in portrait."),
        R("Turn on the phone’s dark theme. The app keeps its own sky-blue look and stays readable."),
        R("On the smallest phone you have, nothing on the home screen, onboarding or the alarm screen is cut off or overlapping."),
        R("With gesture navigation and with 3-button navigation, the tab bar and the DISARM button are not hidden behind the system bar."),
    ]),
    ("Accessibility", "Turn on TalkBack for this section.", [
        R("The idle shield is read as <code>Touch alert off. Tap to arm.</code> and, once armed, as <code>Touch alert armed. Tap to disarm.</code>", "talkback"),
        R("Each guard card is read with its name, emoji and whether it is selected, for example <code>Dog, 🐕. Selected.</code>", "talkback"),
        R("The Pocket circle is read as <code>Guard my pocket</code>, and <code>Stop guarding</code> when armed.", "talkback"),
        R("The <code>DISARM</code> button can be found and double-tapped with TalkBack during an alarm.", "talkback", guard=True),
        R("Set Android font size and display size to the largest. Text still fits on home, onboarding and the alarm screen; nothing important is cut off.", "settings"),
    ]),
    ("Stability", "", [
        R("Go through this whole list without the app crashing or showing <code>Guard Dog keeps stopping</code>. Any crash fails this row; write what you were doing in Notes."),
        R("Tap the shield very quickly many times. The app ends in a clear state (armed or not), with one sound at most."),
        R("Switch tabs rapidly while armed and while alarming. Nothing breaks and the alarm screen stays on top."),
        R("Use the phone normally for a day with the app installed but not armed. No unexpected notifications, sounds or battery drain from Guard Dog."),
    ]),
    ("Analytics events", "Only if you have a computer with adb. Run <code>adb logcat -s GuardDogAnalytics</code> and watch the lines as you use the app.", [
        R("First launch logs <code>splash_shown</code> with <code>first_launch=true</code> and <code>splash_completed</code> with <code>ad_skip_reason=first_launch</code>.", "adb"),
        R("Arming Don’t Touch logs <code>touch_alert_armed</code> with the sensitivity.", "adb"),
        R("An alarm logs <code>touch_alert_triggered</code>; disarming logs <code>touch_alert_disarmed</code> with <code>was_alarming</code> right.", "adb"),
        R("Pocket Mode logs <code>pocket_armed</code>, <code>pocket_engaged</code>, <code>pocket_alarm</code> and <code>pocket_disarmed</code> at the matching moments.", "adb"),
        R("After a finished session, <code>interstitial_suppressed</code> or <code>interstitial_shown</code> appears. Never after an alarm dismissal or a countdown cancel.", "adb"),
    ]),
    ("Anything else", "Free exploration. Use the app the way a real person would, for a while.", [
        R("Leave your phone armed on a café or office table while you step away, for real. Note anything confusing in Notes."),
        R("Give the phone to someone who has never seen the app and ask them to protect their phone with it. Note where they hesitated."),
        R("Nothing in the app is in a language other than English, and no text looks like a placeholder or a code name."),
    ]),
    ("Not bugs — please do not file these", "These are deliberate, or known and not part of this build. Mark each one once you have read it.", [
        R("<b>Test ads.</b> Ads say <code>Test Ad</code>. Real ad accounts come before release."),
        R("<b>Test signing.</b> The release-test APK is signed with a development key. It cannot be updated from the Play Store and Play Protect may warn when installing."),
        R("<b>The screen goes black in Pocket Mode</b> when the sensor is covered. That stops your pocket from tapping buttons. It lights up again when uncovered."),
        R("<b>You must unlock to disarm from the notification</b>, and the alarm screen does not show over the lock screen. Otherwise a thief could silence it without your PIN."),
        R("<b>The app turns the alarm volume up to maximum</b> during an alarm, and keeps it there until you disarm. It puts it back afterwards."),
        R("<b>No PIN to disarm, no timeout, no shake-to-stop.</b> DISARM on the unlocked phone is the only way out."),
        R("<b>High sensitivity can go off from table vibration.</b> Known. Section 09 collects data for it."),
        R("<b>Pocket Mode does not send the three “Motion detected!” notifications.</b> Only Don’t Touch does."),
        R("<b>No sensitivity setting in Pocket Mode.</b> Not in this version."),
        R("<b>The “one quick thing” notification explanation before the first arm</b> does not appear, because onboarding already asked about notifications."),
        R("<b>Portrait only, light look only, English only.</b>"),
        R("<b>The launch ad often does not appear</b> on slow networks. It gives up after 5 seconds by design."),
        R("<b>Analytics only go to the phone’s log</b> in this build. Nothing is sent anywhere."),
    ]),
]


def row_html(sec_no, row):
    if isinstance(row, str):
        return f'<li class="grp">{html.escape(row[3:])}</li>'
    text, opts = row
    rid = f"{sec_no:02d}-" + hashlib.sha1(text.encode()).hexdigest()[:8]
    meta = "".join(f'<span class="tag t-{t}">{TAGS[t]}</span>' for t in opts["tags"])
    if opts["req"]:
        meta += f'<span class="req">{html.escape(opts["req"])}</span>'
    meta_html = f'<div class="meta">{meta}</div>' if meta else ""
    guard = ' data-safety="1"' if opts["guard"] else ""
    return (
        f'<li class="row" data-id="{rid}"{guard}><div class="marks">'
        '<button class="mark pass" data-v="pass" aria-label="Mark as passed" type="button">&#10003;</button>'
        '<button class="mark fail" data-v="fail" aria-label="Mark as failed" type="button">&#10007;</button>'
        f'</div><div class="txt">{text}{meta_html}</div></li>'
    )


def build():
    total = guards = 0
    secs, chips = [], []
    last = len(SECTIONS) - 1
    for i, (title, ctx, rows) in enumerate(SECTIONS):
        checks = [r for r in rows if not isinstance(r, str)]
        n = len(checks)
        g = sum(1 for _, o in checks if o["guard"])
        total += n
        guards += g
        heavy = g >= 4
        cls = "sec" + (" safety" if heavy else "") + (" final" if i == last else "")
        chip_cls = "chip" + (" safety" if heavy else "") + (" final" if i == last else "")
        chips.append(f'<a class="{chip_cls}" href="#s{i:02d}" title="{html.escape(title)}">{i:02d}</a>')
        ctx_html = f'\n  <p class="ctx">{ctx}</p>' if ctx else ""
        body = "\n".join(row_html(i, r) for r in rows)
        secs.append(
            f'<section id="s{i:02d}" class="{cls}">\n'
            f'  <div class="head"><span class="num">{i:02d}</span><h2>{html.escape(title)}</h2>'
            f'<span class="badge" data-count>0/{n}</span></div>{ctx_html}\n'
            f'  <ul class="rows">\n{body}\n  </ul>\n</section>'
        )
    today = datetime.date.today().isoformat()
    page = (TEMPLATE
            .replace("%%TOTAL%%", str(total))
            .replace("%%GUARDS%%", str(guards))
            .replace("%%NSEC%%", str(len(SECTIONS)))
            .replace("%%CHIPS%%", "".join(chips))
            .replace("%%SECTIONS%%", "\n".join(secs))
            .replace("%%DATE%%", today)
            .replace("%%BUILD%%", BUILD)
            .replace("%%LAST%%", f"{last:02d}"))
    OUT.write_text(page)
    print(f"Wrote {OUT.name}: {total} checks in {len(SECTIONS)} sections, {guards} guard checks.")


TEMPLATE = r"""<title>Guard Dog QA Checklist</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500;600&family=IBM+Plex+Sans:wght@400;500;600;700&display=swap">
<style>
  /* Layout: one reading column under a sticky header: a progress readout drawn like the
     app's arming bar, and a strip of section chips. Night-watch navy first, sky-blue
     signals from the app's own palette; light theme is the app's daytime sky. */
  :root {
    --bg: #0D1626; --surface: #132036; --raised: #1A2A44; --line: #283B5A;
    --ink: #E6EEF8; --dim: #8EA2BF;
    --brand: #5BB8FF;
    --signal: #34D27B; --stop: #F06A5B; --warn: #F2B14A;
    --onSignal: #0B1A12;
    --signalWash: rgba(52,210,123,.10); --stopWash: rgba(240,106,91,.12); --warnWash: rgba(242,177,74,.11);
    --sans: "IBM Plex Sans", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    --mono: "IBM Plex Mono", ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
    color-scheme: dark;
  }
  @media (prefers-color-scheme: light) { :root:not([data-theme="dark"]) {
    --bg: #EAF3FC; --surface: #FFFFFF; --raised: #DCEAF8; --line: #BCD2EA;
    --ink: #14233D; --dim: #4F6383;
    --brand: #2D7FF9;
    --signal: #157A47; --stop: #B5362A; --warn: #8F600E;
    --onSignal: #FFFFFF;
    --signalWash: rgba(21,122,71,.08); --stopWash: rgba(181,54,42,.08); --warnWash: rgba(143,96,14,.09);
    color-scheme: light;
  } }
  :root[data-theme="light"] {
    --bg: #EAF3FC; --surface: #FFFFFF; --raised: #DCEAF8; --line: #BCD2EA;
    --ink: #14233D; --dim: #4F6383;
    --brand: #2D7FF9;
    --signal: #157A47; --stop: #B5362A; --warn: #8F600E;
    --onSignal: #FFFFFF;
    --signalWash: rgba(21,122,71,.08); --stopWash: rgba(181,54,42,.08); --warnWash: rgba(143,96,14,.09);
    color-scheme: light;
  }

  * { box-sizing: border-box; }
  /* Fallback only: script measures the header and sets the real value. */
  html { scroll-padding-top: 200px; }
  body {
    margin: 0; background: var(--bg); color: var(--ink);
    font: 16px/1.62 var(--sans); -webkit-text-size-adjust: 100%;
  }
  .wrap { max-width: 900px; margin: 0 auto; padding: 0 20px 80px; }
  code {
    font-family: var(--mono); font-size: .86em; background: var(--raised); border: 1px solid var(--line);
    border-radius: 5px; padding: .06em .36em; word-break: break-word;
  }
  b { font-weight: 600; }

  header {
    position: sticky; top: env(safe-area-inset-top, 0px); z-index: 20;
    background: var(--surface); border-bottom: 1px solid var(--line);
  }
  .hin { max-width: 900px; margin: 0 auto; padding: 14px 20px 10px; }
  .brand { display: flex; align-items: center; gap: 10px; }
  .brand svg { flex: 0 0 auto; }
  h1 { font-size: 18px; margin: 0; letter-spacing: -.01em; font-weight: 600; text-wrap: balance; }
  .sub { color: var(--dim); font-size: 13px; margin: 1px 0 12px; }

  .timelab { display: flex; justify-content: space-between; gap: 12px; font-size: 12.5px; color: var(--dim); margin-bottom: 7px; }
  .timelab b { color: var(--ink); font-family: var(--mono); font-weight: 500; font-variant-numeric: tabular-nums; }
  .meter { height: 6px; border-radius: 99px; background: var(--raised); overflow: hidden; display: flex; }
  .meter i { display: block; height: 100%; width: 0; transition: width .18s ease; }
  .meter .p { background: var(--signal); }
  .meter .f { background: var(--stop); }

  .tally { display: flex; align-items: center; gap: 14px; flex-wrap: wrap; margin-top: 9px; font-size: 13px; color: var(--dim); }
  .tally b { font-family: var(--mono); font-weight: 500; font-variant-numeric: tabular-nums; }
  .tally .g { color: var(--signal); } .tally .r { color: var(--stop); } .tally .w { color: var(--warn); }
  .tally .spacer { flex: 1; }
  .btn {
    font: inherit; font-size: 12.5px; color: var(--ink); background: var(--raised);
    border: 1px solid var(--line); border-radius: 8px; padding: 5px 11px; cursor: pointer; min-height: 32px;
  }
  .btn:hover { border-color: var(--dim); }
  .btn.arm { background: var(--stopWash); border-color: var(--stop); color: var(--stop); }

  nav { display: flex; gap: 5px; flex-wrap: wrap; margin-top: 10px; }
  .chip {
    font-family: var(--mono); font-size: 11.5px; text-decoration: none; color: var(--dim);
    border: 1px solid var(--line); border-radius: 6px; padding: 2px 7px; background: var(--bg);
  }
  .chip:hover { color: var(--ink); border-color: var(--dim); }
  .chip.safety { border-color: var(--warn); color: var(--warn); }
  .chip.final { border-style: dashed; }
  .chip.done { background: var(--signalWash); border-color: var(--signal); color: var(--signal); }
  .chip.bad { background: var(--stopWash); border-color: var(--stop); color: var(--stop); }
  /* `current` uses a ring and weight so it can show together with `done` or `bad`, which own colour. */
  .chip.current { box-shadow: 0 0 0 2px var(--ink); font-weight: 600; }

  .warnbox {
    margin-top: 9px; padding: 8px 12px; border-radius: 8px; font-size: 13px;
    background: var(--stopWash); border: 1px solid var(--stop);
  }

  .intro { margin: 28px 0 0; max-width: 68ch; }
  .intro p { margin: 0 0 11px; }
  .intro p:first-child { font-size: 17px; }
  .legend { display: flex; flex-wrap: wrap; gap: 6px 14px; margin: 14px 0 0; font-size: 13px; color: var(--dim); align-items: center; }
  .field { margin: 22px 0 4px; }
  .field label { display: block; font-size: 11.5px; letter-spacing: .1em; text-transform: uppercase; color: var(--dim); margin-bottom: 6px; font-weight: 500; }
  textarea {
    width: 100%; font: inherit; font-size: 14px; color: var(--ink); background: var(--surface);
    border: 1px solid var(--line); border-radius: 10px; padding: 11px 13px; resize: vertical;
  }
  textarea:focus-visible, .btn:focus-visible, .mark:focus-visible, .chip:focus-visible {
    outline: 2px solid var(--brand); outline-offset: 2px;
  }

  .sec { margin-top: 44px; }
  .head { display: flex; align-items: baseline; gap: 11px; border-bottom: 1px solid var(--line); padding-bottom: 7px; }
  .num { font-family: var(--mono); font-size: 13px; color: var(--brand); }
  .sec.safety .num { color: var(--warn); }
  .head h2 { font-size: 13px; letter-spacing: .12em; text-transform: uppercase; margin: 0; flex: 1; font-weight: 600; text-wrap: balance; }
  .badge { font-family: var(--mono); font-size: 11.5px; color: var(--dim); font-variant-numeric: tabular-nums; white-space: nowrap; }
  .badge.done { color: var(--signal); }
  .ctx { margin: 12px 0 0; padding: 10px 13px; font-size: 14px; color: var(--dim); background: var(--raised); border-radius: 8px; max-width: 72ch; }
  .sec.safety .ctx { background: var(--warnWash); color: var(--ink); }

  ul.rows { list-style: none; margin: 6px 0 0; padding: 0; }
  .grp {
    font-size: 11.5px; letter-spacing: .1em; text-transform: uppercase; color: var(--dim); font-weight: 500;
    margin: 20px 0 2px; padding-top: 9px; border-top: 1px dashed var(--line);
  }
  .row { display: flex; gap: 11px; align-items: flex-start; padding: 9px 10px 9px 8px; border-radius: 9px; border: 1px solid transparent; }
  .row + .row { margin-top: 1px; }
  .row .txt { flex: 1; min-width: 0; padding-top: 1px; }
  .row[data-safety]::before {
    content: ""; flex: 0 0 3px; align-self: stretch; border-radius: 2px; background: var(--warn); margin-right: -4px;
  }
  .row[data-m="pass"] { background: var(--signalWash); }
  .row[data-m="pass"] .txt { color: var(--dim); }
  .row[data-m="fail"] { background: var(--stopWash); border-color: var(--stop); }
  .row[data-m="fail"] .txt { font-weight: 500; }

  .meta { display: flex; flex-wrap: wrap; gap: 5px; margin-top: 5px; }
  .tag, .req { font-size: 11px; line-height: 1.5; border-radius: 5px; padding: 0 6px; white-space: nowrap; }
  .tag { border: 1px solid var(--line); color: var(--dim); }
  .req { font-family: var(--mono); color: var(--dim); background: var(--raised); }
  .safety-key { display: inline-flex; align-items: center; gap: 6px; }
  .safety-key::before { content: ""; width: 3px; height: 14px; border-radius: 2px; background: var(--warn); }

  .marks { display: flex; gap: 5px; flex: 0 0 auto; }
  .mark {
    width: 32px; height: 32px; border-radius: 8px; cursor: pointer; font-size: 14px; line-height: 1;
    background: var(--bg); border: 1px solid var(--line); color: var(--dim); padding: 0;
  }
  .mark:hover { border-color: var(--dim); }
  .row[data-m="pass"] .mark.pass { background: var(--signal); border-color: var(--signal); color: var(--onSignal); }
  .row[data-m="fail"] .mark.fail { background: var(--stop); border-color: var(--stop); color: var(--onSignal); }

  footer { margin-top: 56px; padding-top: 16px; border-top: 1px solid var(--line); color: var(--dim); font-size: 12.5px; }

  @media (max-width: 560px) {
    .wrap, .hin { padding-left: 16px; padding-right: 16px; }
    body { font-size: 15px; }
    .row { padding: 8px 4px; }
  }
  @media (prefers-reduced-motion: reduce) { * { transition: none !important; } }
</style>

<header>
  <div class="hin">
    <div class="brand">
      <svg width="20" height="24" viewBox="0 0 20 24" aria-hidden="true">
        <path d="M10 1 1.5 4.6v6.2c0 5.6 3.6 10.6 8.5 12.2 4.9-1.6 8.5-6.6 8.5-12.2V4.6L10 1Z" fill="var(--brand)"/>
        <g fill="var(--surface)"><ellipse cx="10" cy="14.2" rx="3" ry="2.5"/><circle cx="6.4" cy="10.4" r="1.25"/><circle cx="8.7" cy="8.7" r="1.25"/><circle cx="11.3" cy="8.7" r="1.25"/><circle cx="13.6" cy="10.4" r="1.25"/></g>
      </svg>
      <h1>Guard Dog — manual QA</h1>
    </div>
    <p class="sub">One pass over everything a person can see, hear or feel in Android build %%BUILD%%.</p>
    <div class="timelab"><span>Checks done</span><span><b id="nd">0</b> of <b>%%TOTAL%%</b></span></div>
    <div class="meter" aria-hidden="true"><i class="p"></i><i class="f"></i></div>
    <div class="tally">
      <span class="g"><b id="np">0</b> passed</span>
      <span class="r"><b id="nf">0</b> failed</span>
      <span class="w"><b id="ns">0</b> guard failures</span>
      <span class="spacer"></span>
      <button class="btn" id="copy" type="button">Copy report</button>
      <button class="btn" id="reset" type="button">Reset</button>
    </div>
    <div class="warnbox" id="warn" role="status" hidden></div>
    <nav aria-label="Sections">%%CHIPS%%</nav>
  </div>
</header>

<div class="wrap">
  <div class="intro">
    <p>This is a full manual pass over Guard Dog for Android. It is written for someone who did not
      build the app. Every row is one thing you can look at, listen to or feel, and answer yes or no about.</p>
    <p>Tap <b>&#10003;</b> if it behaves as described, <b>&#10007;</b> if it does not. Tap the same
      mark again to clear it. Your marks, the device box and your notes are saved in this browser,
      so you can close the page and come back. When you finish, <b>Copy report</b> puts a summary of
      every failure on your clipboard.</p>
    <p>Rows with an amber edge are <b>guard checks</b>: places where a failure means the phone is not
      really protected, a thief could silence the alarm, or the user is told they are guarded when
      they are not. A failure there matters more than any other. Sections with an amber chip are
      full of them.</p>
    <p><b>Read section %%LAST%%, &ldquo;Not bugs&rdquo;, before you start.</b></p>
    <div class="legend">
      <span class="safety-key">Guard check</span>
      <span><span class="tag">Locked phone</span> what the row needs</span>
      <span><span class="req">§1.2</span> the spec section it checks, in <code>ANDROID_HANDOFF.md</code></span>
    </div>
  </div>

  <div class="field">
    <label for="device">Device and build</label>
    <textarea id="device" rows="2" placeholder="Phone model, Android version, and which APK (release-test or debug)"></textarea>
  </div>

%%SECTIONS%%

  <div class="field" style="margin-top:44px">
    <label for="notes">Notes</label>
    <textarea id="notes" rows="7" placeholder="Anything that surprised you, or that no row covers. Per-brand answers (locked torch, locked pocket mode, 30-minute battery) go here. Rough timings help."></textarea>
  </div>

  <footer>
    Generated %%DATE%% from the Android app as built. %%TOTAL%% checks in %%NSEC%% sections, %%GUARDS%% of them guard checks.<br>
    Regenerate with <code>python3 scripts/gen-qa-doc.py</code>. Edit that file, not this one.
  </footer>
</div>

<script>
  var DOC_TITLE = 'Guard Dog — manual QA checklist (Android build %%BUILD%%)';
  var KEY = 'guarddog-android-qa-v1';
  var store = {};

  // Prove storage works before relying on it. A silent failure here means a tester marks a
  // hundred rows and loses them on reload without warning, so say so up front.
  var CAN_STORE = (function () {
    try { localStorage.setItem(KEY + '-probe', '1'); localStorage.removeItem(KEY + '-probe'); return true; }
    catch (e) { return false; }
  })();
  if (CAN_STORE) {
    try { store = JSON.parse(localStorage.getItem(KEY) || '{}') || {}; } catch (e) { store = {}; }
  } else {
    showWarn('<b>Your marks will not be saved.</b> This browser is blocking storage for this page. ' +
      'Save the file and open it directly, or use <b>Copy report</b> often so nothing is lost.');
  }
  function save() { if (!CAN_STORE) return; try { localStorage.setItem(KEY, JSON.stringify(store)); } catch (e) {} }
  function showWarn(h) { var w = document.getElementById('warn'); w.innerHTML = h; w.hidden = false; syncAnchorOffset(); }

  var rows = Array.prototype.slice.call(document.querySelectorAll('.row'));
  var TOTAL = rows.length;

  function apply(row) {
    var v = store[row.dataset.id];
    if (v) row.setAttribute('data-m', v); else row.removeAttribute('data-m');
    row.querySelectorAll('.mark').forEach(function (b) { b.setAttribute('aria-pressed', String(v === b.dataset.v)); });
  }

  function refresh() {
    var pass = 0, fail = 0, sfail = 0;
    rows.forEach(function (r) {
      var v = store[r.dataset.id];
      if (v === 'pass') pass++;
      else if (v === 'fail') { fail++; if (r.hasAttribute('data-safety')) sfail++; }
    });
    document.querySelector('.meter .p').style.width = (pass / TOTAL * 100) + '%';
    document.querySelector('.meter .f').style.width = (fail / TOTAL * 100) + '%';
    document.getElementById('np').textContent = pass;
    document.getElementById('nf').textContent = fail;
    document.getElementById('ns').textContent = sfail;
    document.getElementById('nd').textContent = pass + fail;
    document.querySelectorAll('.sec').forEach(function (sec) {
      var rs = sec.querySelectorAll('.row'), done = 0, bad = 0;
      rs.forEach(function (r) { var v = store[r.dataset.id]; if (v) done++; if (v === 'fail') bad++; });
      var b = sec.querySelector('[data-count]');
      b.textContent = done + '/' + rs.length;
      b.classList.toggle('done', done === rs.length);
      var chip = document.querySelector('.chip[href="#' + sec.id + '"]');
      if (chip) { chip.classList.toggle('done', done === rs.length && bad === 0); chip.classList.toggle('bad', bad > 0); }
    });
  }

  document.addEventListener('click', function (e) {
    var btn = e.target.closest('.mark');
    if (!btn) return;
    var row = btn.closest('.row'), id = row.dataset.id;
    if (store[id] === btn.dataset.v) delete store[id]; else store[id] = btn.dataset.v;
    apply(row); save(); refresh();
  });

  ['device', 'notes'].forEach(function (k) {
    var el = document.getElementById(k);
    el.value = store['_' + k] || '';
    el.addEventListener('input', function () { store['_' + k] = el.value; save(); });
  });

  function flash(btn, text) {
    var old = btn.dataset.label || btn.textContent; btn.dataset.label = old;
    btn.textContent = text; setTimeout(function () { btn.textContent = old; }, 1600);
  }

  document.getElementById('copy').addEventListener('click', function () {
    var lines = [], n = 0, ns = 0;
    document.querySelectorAll('.sec').forEach(function (sec) {
      var name = sec.querySelector('h2').textContent.trim(), num = sec.querySelector('.num').textContent;
      sec.querySelectorAll('.row').forEach(function (r) {
        if (store[r.dataset.id] !== 'fail') return;
        n++;
        var guard = r.hasAttribute('data-safety');
        if (guard) ns++;
        var reqs = Array.prototype.map.call(r.querySelectorAll('.req'), function (q) { return q.textContent; }).join(', ');
        var txt = r.querySelector('.txt').cloneNode(true);
        var meta = txt.querySelector('.meta'); if (meta) meta.remove();
        lines.push((guard ? 'GUARD FAILED' : 'FAILED') + ' [' + num + ' ' + name + ']' + (reqs ? ' (' + reqs + ')' : ''));
        lines.push('  ' + txt.textContent.replace(/\s+/g, ' ').trim());
      });
    });
    var pass = rows.filter(function (r) { return store[r.dataset.id] === 'pass'; }).length;
    var body = [
      DOC_TITLE, new Date().toLocaleString(), '',
      'Device / build: ' + (document.getElementById('device').value.trim() || '(not given)'),
      'Checked ' + (pass + n) + ' of ' + TOTAL + ': ' + pass + ' passed, ' + n + ' failed' + (ns ? ' (' + ns + ' guard)' : '') + '.',
    ];
    if (n) { body.push(''); body = body.concat(lines); }
    var notes = document.getElementById('notes').value.trim();
    var text = body.concat(notes ? ['', 'NOTES', notes] : []).join('\n');
    var btn = this;

    // The clipboard can be refused (some app views). Then the report goes at the top of Notes,
    // where it can be selected and copied by hand — never an alert, which some viewers swallow.
    function fallback() {
      var el = document.getElementById('notes');
      el.value = body.join('\n') + '\n\n---\n' + el.value;
      store._notes = el.value; save();
      el.focus(); el.setSelectionRange(0, body.join('\n').length);
      showWarn('Clipboard unavailable here, so the report was put at the top of <b>Notes</b> and selected. Copy it from there.');
    }
    try {
      navigator.clipboard.writeText(text).then(function () { flash(btn, 'Copied'); }, fallback);
    } catch (e) { fallback(); }
  });

  // Two taps to reset: confirm() dialogs are not shown everywhere this page may be opened.
  var resetTimer = null;
  document.getElementById('reset').addEventListener('click', function () {
    var b = this;
    if (!b.classList.contains('arm')) {
      b.classList.add('arm'); b.textContent = 'Tap again to clear everything';
      resetTimer = setTimeout(function () { b.classList.remove('arm'); b.textContent = 'Reset'; }, 4000);
      return;
    }
    clearTimeout(resetTimer);
    b.classList.remove('arm'); b.textContent = 'Reset';
    store = {}; save();
    document.getElementById('device').value = '';
    document.getElementById('notes').value = '';
    rows.forEach(apply); refresh();
  });

  // ---- which section is in view ----
  var secs = Array.prototype.slice.call(document.querySelectorAll('.sec'));
  var ticking = false;
  function anchorOffset() { return document.querySelector('header').offsetHeight + 12; }
  function syncAnchorOffset() { document.documentElement.style.scrollPaddingTop = anchorOffset() + 'px'; }
  function markCurrent() {
    ticking = false;
    var line = anchorOffset() + 4, cur = null;
    for (var i = 0; i < secs.length; i++) if (secs[i].getBoundingClientRect().top - line <= 0) cur = secs[i];
    if (window.innerHeight + window.scrollY >= document.documentElement.scrollHeight - 4) cur = secs[secs.length - 1];
    if (!cur) cur = secs[0];
    secs.forEach(function (s) {
      var chip = document.querySelector('.chip[href="#' + s.id + '"]');
      if (!chip) return;
      chip.classList.toggle('current', s === cur);
      if (s === cur) chip.setAttribute('aria-current', 'true'); else chip.removeAttribute('aria-current');
    });
  }
  function onScroll() { if (!ticking) { ticking = true; requestAnimationFrame(markCurrent); } }
  window.addEventListener('scroll', onScroll, { passive: true });
  window.addEventListener('resize', function () { syncAnchorOffset(); onScroll(); });
  window.addEventListener('hashchange', onScroll);

  rows.forEach(apply);
  refresh();
  syncAnchorOffset();
  markCurrent();
</script>
"""

if __name__ == "__main__":
    build()
