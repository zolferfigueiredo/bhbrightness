# Contributing

Thanks for helping with BeeHan Brightness. Bug reports, ideas, translations and code are all welcome.

## Issues

- **Bugs and ideas**: [open an issue](https://github.com/zolferfigueiredo/bhbrightness/issues/new/choose). Search the open ones first.
- **Security problems**: don't open an issue. Follow the [security policy](SECURITY.md).

## Pull requests

For anything bigger than a small fix, open an issue first so we can agree on the idea before you build it.

1. Fork the repository and branch from `main`.
2. Make your change. `./run.sh` builds and runs a debug copy in the terminal, and `swift test` runs the tests. You need a Mac with a built-in display, macOS 13 or later and Xcode 16. The debug copy needs Accessibility access for your terminal app.
3. If you changed the app (anything in `Sources`, `icon.svg` or `Package.swift`), raise `VERSION` in `build.sh`, for example 1.2.3 to 1.2.4.
4. Open a pull request against `main`.

CI builds and tests it on macOS and runs the tests again on Linux, counting any compiler warning as an error. It also runs shellcheck on the scripts and checks that the version went up.

## Translations

Each language has its own file in [`Sources/BeeHanBrightness/Strings`](../Sources/BeeHanBrightness/Strings). To fix a translation, edit that file. The tests check that every language has every string and keeps placeholders like `{version}`.

## License

By contributing, you agree that your work is licensed under the [MIT License](../LICENSE).
