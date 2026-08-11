# Template: copy to <flutter-project>/justfile and adapt.
# Discovery: `just --list`, `jc` (fzf chooser), or :OverseerRun in Neovim.

default:
    @just --list

run:
    flutter run

test:
    flutter test

analyze:
    flutter analyze

format:
    dart format lib test

build-ios:
    flutter build ios

clean:
    flutter clean
