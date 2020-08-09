# Conway's Game of Life

This is an implementation of Conway's Game of Life, made using Zig (compiled to
WASM) and the canvas API.

## Build Instructions

This game was built with Zig `0.6.0+df1a2ecd3`. Make sure you have at least that
version or newer. As Zig is still pre-1.0, the build may break. Please file an
issue if the build breaks!

Anyway, once you have Zig installed, do the following:

```bash
$ git clone https://github.com/leroycep/game-of-life.git --recursive
$ cd game-of-life
$ zig build wasm
$ # Run some kind of http server, I use the python livereload
$ livereload zig-cache/www/
```

Then open up the webpage in a browser.

Also note the `--recursive`. This flag tells `git` to automatically download
submodules, which I use to depend on [`zee_alloc`][].

[`zee_alloc`]: https://github.com/fengb/zee_alloc

## Future Features

This project was originally done as part of a Computer Science build week at
[Lambda School][]. I had a bunch of features that I wanted to implement, and of
course I couldn't do everything in a week, especially since I implemented the
GUI code mostly from scratch. Here's a list of what I might add in the future,
given I have the time.

[lambda school]: https://lambdaschool.com/

- [x] Infinite Grid
  - I had a plan to split the grid into a bunch of chunks, and then only keep
    active chunks loaded.
  - This would've been so cool! But I decided to focus on making the app more
    usable first
- [ ] Saving and Loading Worlds
- [ ] Importing and Exporting schematics
  - I wanted some way of sharing cool designs with other people
  - The clipboard system was the first step towards this
- [ ] Rotating the clipboard
  - Placing schmatics is cool and all, but I need my gliders to go in arbitrary
    directions!
  - Nobodies got time to draw everything out!
- [ ] Native Application
  - I got an initial implementation of the app working using SDL and
    [Pathfinder][], but I stopped supporting it so I could spend more time on
    features.
  - That said, most of the code is written with native support in mind. Porting
    wouldn't require reimplementing everything.

[pathfinder]: https://github.com/servo/pathfinder
