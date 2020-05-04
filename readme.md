# About

Raytracer benchmarks based on [Typescript](http://www.typescriptlang.org) sample.

## Results

| Language / Compiler  | Time [ms] |
| -------------------- | --------- |
| C++ (GCC)            | 160 ms    |
| Fortran              | 160 ms    |
| C (GCC)              | 160 ms    |
| D (LDC)              | 210 ms    |
| C (MSVC)             | 250 ms    |
| C++ (MSVC)           | 250 ms    |
| VB.NET               | 360 ms    |
| C#                   | 360 ms    |
| Delphi XE6           | 390 ms    |
| Go                   | 460 ms    |
| D (DMD)              | 500 ms    |
| Java 8-14            | 600 ms    |
| Delphi 2010 (32 bit) | 720 ms    |
| Julia                | 900 ms    |
| Nim                  | 1500 ms   |
| F#                   | 1800 ms   |
| Node                 | 1800 ms   |
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
| Odin                 | ? ms      |
| Swift                | ? ms      |
| Haskel               | ? ms      |

## Lines of code

| Language   | Loc |
| ---------- | --- |
| Python     | 275 |
| F#         | 300 |
| Ruby       | 351 |
| Julia      | 360 |
| Typescript | 412 |
| Nim        | 418 |
| C#         | 426 |
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

**C** - Simple, clean and fast

**C++** - Unlike C, C++ version does bounds checking, otherwise performaces are mostly the same

**Nim** - Currently raytracer implementation is not optimized well

**Delphi2010** - Uses old 32 bit compiler

**Node/V8** - It's blazing fast keeping in mind that it has to make sense out of javascript

**PHP7** - For interpreted language (without JIT) this is close to what is possible to get

**Fortran** - Finally completed fortran port, it was much easier then expected

## Tested On

All tests are done on AMD FX-8120 cpu.
