# aoc zig

[Advent of Code](https://adventofcode.com/) challenge implementations in Zig

includes scaffolding for running and adding challenges for specific days and years

## run

you can run a specific challenge with `zig build run -Dyear=<year> -Dday=<day> -Dpart=<part>`

- just using `zig build` also works, as `run` is the default step
- if year is omitted, run the latest existing year
- if day is omitted, run the latest day for the given year
- if part is omitted, run both parts. options are: `1, 2, all`
- can run tests instead with `-Dtest`
- can also use `-Drun-all` to run all days for a given year

## add

you can add a new challenge with `zig build add -Dyear=<year> -Dday=<day>`

- if year is omitted, add setup for the latest existing year
- if day is omitted, add a new day after the lastest one for the given year
