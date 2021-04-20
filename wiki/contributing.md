# Contributing Guide

## Step by Step
1. Fork. Make a your own copy.
2. Work on your copy. (I recommend you to work on the `develop` branch, but `master` is okay)
3. Make a pull request to `develop` branch in this repo.
4. I will merge acceptable commits.
5. Then, i will merge commits from `develop` to `master` when the code is runnable. Just wait.

## Difference between `master` and `develop`
- `master` is the public branch, saved latest code can run and pass tests.
- `develop` is the private branch own by maintainer to merge latest changes from any other people and maintainer. Maintainer should merge `master` from `develop` when the code from `develop` can run correctly.

## Code Style
Personally I use extension `sumneko.lua` for Visual Studio Code to format code. Any code with likely style is welcome. Don't wrroy about that, I won't refuse a PR just because the style and I may format your code manually if your PR is worth. But that will add a external commit and it's very ugly tough.  
That rule might be changed in future.

## Releases
The code in `master` branch is developing version still. When releaseing one version, the bumpping commit will be tagged and a new `Release` will be published in GitHub (sometimes later).
