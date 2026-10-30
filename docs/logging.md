# Read app logs

Status: guide for the current app. Commands are read-only.

The app uses the macOS unified logging system. Terminal is a command-line app; Console is a separate graphical log viewer. Both can read the same logs. Xcode can show logs while debugging. See [Apple's viewing guide](https://developer.apple.com/documentation/os/viewing-log-messages).

## Terminal

Start a live stream before you reproduce an issue:

```sh
/usr/bin/log stream --style compact --level debug \
  --predicate 'subsystem == "STTPOC"'
```

In another terminal, run `./scripts/run-local.sh` from the repository root. Use fictional practice input. Press Control-C in the log terminal to end the stream; the app stays open.

To show only recording cleanup messages, add the category filter:

```sh
/usr/bin/log stream --style compact --level debug \
  --predicate 'subsystem == "STTPOC" AND category == "AudioCapture"'
```

To read retained messages from the last 30 minutes:

```sh
/usr/bin/log show --last 30m --style compact --info --debug \
  --predicate 'subsystem == "STTPOC"'
```

`stream` watches new messages. `show` reads retained history. The flags include available info and debug messages; they do not add log calls or recover messages that macOS did not retain. Use `/usr/bin/log help stream` or `/usr/bin/log help show` for local command help.

## What to expect

The [application log catalog](log-catalog.md) defines the current categories, levels, messages, triggers, and expected silence. Read it to select a filter and interpret results. The [logging convention](conventions/logging.md) defines when to add logs and how to maintain the catalog.

Start with the subsystem filter if a category filter gives no results. Start the stream before the action and use `show` for earlier retained messages. The app does not create a repository log file. Benchmark progress printed to stderr is separate from unified logging.

## Console

Open Console, select your Mac, and start streaming. Filter by subsystem `STTPOC`; add category `AudioCapture` or `WhisperSession` as needed. Console is useful for browsing messages without command-line predicates.

## Xcode

Open `Package.swift` in Xcode. Select the `STTPractice` executable scheme and run it on your Mac. Show the debug console and filter for the cleanup message text. Xcode is useful when you also need breakpoints or variable inspection. Use the packaged app through `run-local.sh` for the normal app workflow; an Xcode launch can use a different microphone permission identity.

## Data and limits

Each catalog entry defines its data policy. Read the [private-data rules](conventions/private-data.md) before saving or sharing diagnostic output.
