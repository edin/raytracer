# About

Raytracer benchmarks based on [Typescript](http://www.typescriptlang.org) sample.

## Results

Language / Compiler       | Time [ms]    | Loc
------------------------- | -------------|--------------
C (GCC)                   | 160 ms       | 641
D (LDC)                   | 210 ms       | 468
C (MSVC)                  | 250 ms       |
C++ (MSVC)                | 250 ms       | 475
C++ (GCC)                 | 330 ms       |
C#                        | 360 ms       | 426
VB.NET                    | 360 ms       | 406
Delphi XE6                | 390 ms       | 678
Go                        | 460 ms       | 529
D (DMD)                   | 500 ms       |
Java 9                    | 600 ms       | 521
Delphi 2010 (32 bit)      | 720 ms       |
Nim                       | 1500 ms      | 418
Node                      | 4000 ms      | 322
HHVM                      | 11000 ms     |
PHP (PHP 7.3)             | 23500 ms     | 535
PHP (PHP 7.0)             | 25500 ms     |
Ruby 2.2                  | 47800 ms     | 351
Python 3.5                | 68000 ms     | 275
PHP (PHP 5.6)             | 83000 ms     |
Fortran                   | ? ms         | 610
Zig                       | ? ms         |
V                         | ? ms         |
Odin                      | ? ms         |
Swift                     | ? ms         |
Julia                     | ? ms         |
F#                        | 1800 ms      | 300
Haskel                    | ? ms         |

## Comments:
**C** - Simple

**C++** - Unlike C, C++ version does bounds checking, otherwise performaces are mostly the same

**Nim** - Currently raytracer implementation is not optimized well

**Delphi2010** - Uses old 32 bit compiler

**Node/V8** - It's blazing fast keeping in mind that it has to make sense out of javascript

**PHP7** - For interpreted language this is close to what is possible to get

**Fortran** - Code is mostly there but when i found out how to write binary file i can ensure that it actually works

## Tested On
All tests are done on old AMD FX-8120 processor.