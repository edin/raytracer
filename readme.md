# About

Raytracer benchmarks based on [Typescript](http://www.typescriptlang.org) sample.

## Results

| Language / Compiler  | Time [ms] |
| -------------------- | --------- |
| Nim                  | 130 ms    |
| C++ (GCC)            | 160 ms    |
| Fortran              | 160 ms    |
| C (GCC)              | 160 ms    |
| Crystal              | 190 ms    |
| D (LDC)              | 210 ms    |
| Rust                 | 220 ms    |
| C (MSVC)             | 250 ms    |
| C++ (MSVC)           | 250 ms    |
| VB.NET               | 360 ms    |
| C#                   | 360 ms    |
| Delphi XE6           | 390 ms    |
| Odin                 | 450 ms    |
| Go                   | 460 ms    |
| D (DMD)              | 500 ms    |
| Java 8-14            | 600 ms    |
| Delphi 2010 (32 bit) | 720 ms    |
| Node 15 (JS)         | 734 ms    |
| Julia                | 900 ms    |
| Node 15 (TS)         | 1100 ms   |
| F#                   | 1800 ms   |
| Node 8               | 1800 ms   |
| PHP (PHP 8.0)        | 7450 ms   |
| HHVM                 | 11000 ms  |
| PHP (PHP 7.4)        | 24500 ms  |
| PHP (PHP 7.3)        | 23500 ms  |
| PHP (PHP 7.0)        | 25500 ms  |
| Ruby 2.6             | 37600 ms  |
| Ruby 2.2             | 47800 ms  |
| Python 3.7           | 61000 ms  |
| Python 3.5           | 68000 ms  |
| PHP (PHP 5.6)        | 83000 ms  |
| Zig                  | ? ms      |
| V                    | ? ms      |
| Swift                | ? ms      |
| Haskel               | ? ms      |
| Swift                | ? ms      |
| Scala                | ? ms      |
| Ada                  | ? ms      |

## Lines of code

| Language   | Loc |
| ---------- | --- |
| Python     | 275 |
| F#         | 300 |
| Ruby       | 351 |
| Julia      | 360 |
| Nim        | 379 |
| Typescript | 412 |
| C#         | 426 |
| Swift      | 450 |
| C++        | 461 |
| VB.NET     | 481 |
| D          | 490 |
| PHP        | 491 |
| Go         | 529 |
| C          | 560 |
| Fortran    | 565 |
| Java       | 569 |
| Delphi     | 678 |

## Comments:

**C** - Simple, clean, and fast

**C++** - Unlike C, C++ version does bounds checking, otherwise performances are mostly the same

**Nim** - Uses Quake square root algorithm

**Delphi2010** - Uses old 32 bit compiler

**Node/V8** - Node is fast

**Fortran** - Finally completed Fortran port, it was easier than expected

**F#** - This should be close to C# and VB.Net but I don't have much experience with F#


## Tested On

All tests are done on AMD FX-8120 CPU.